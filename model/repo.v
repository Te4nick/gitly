module model

import veb
import git
import os
import time

pub struct Repo {
pub:
	id                 int @[primary; sql: serial]
	git_dir            string
	name               string
	user_id            int
	user_name          string
	clone_url          string @[skip]
	primary_branch     string
	description        string
	is_public          bool
	users_contributed  []string @[skip]
	users_authorized   []string @[skip]
	nr_topics          int      @[skip]
	views_count        int
	latest_update_hash string    @[skip]
	latest_activity    time.Time @[skip]
pub mut:
	webhook_secret  string
	tags_count      int
	nr_open_issues  int @[orm: 'open_issues_count']
	nr_open_prs     int @[orm: 'open_prs_count']
	nr_releases     int @[orm: 'releases_count']
	nr_branches     int @[orm: 'branches_count']
	nr_tags         int
	nr_stars        int        @[orm: 'stars_count']
	lang_stats      []LangStat @[skip]
	created_at      int
	nr_contributors int
	labels          []Label @[skip]
	status          RepoStatus
	msg_cache       map[string]string @[skip]
}

fn get_declension_form(count int, first_form string, second_form string) string {
	return '<b>${count}</b> ${if count == 1 {first_form} else {second_form}}'
}

pub fn (r &Repo) format_nr_branches() veb.RawHtml {
	return get_declension_form(r.nr_branches, 'branch', 'branches')
}

pub fn (r &Repo) format_nr_tags() veb.RawHtml {
	return get_declension_form(r.nr_tags, 'tag', 'tags')
}

pub fn (r &Repo) format_nr_open_prs() veb.RawHtml {
	return get_declension_form(r.nr_open_prs, 'pull request', 'pull requests')
}

pub fn (r &Repo) format_nr_open_issues() veb.RawHtml {
	return get_declension_form(r.nr_open_issues, 'issue', 'issues')
}

pub fn (r &Repo) format_nr_contributors() veb.RawHtml {
	return get_declension_form(r.nr_contributors, 'contributor', 'contributors')
}

pub fn (r &Repo) format_nr_topics() veb.RawHtml {
	return get_declension_form(r.nr_topics, 'Discussion', 'discussions')
}

pub fn (r &Repo) format_nr_releases() veb.RawHtml {
	return get_declension_form(r.nr_releases, 'release', 'releases')
}

pub fn (r &Repo) parse_ls(ls_line string, branch string) ?File {
	ls_line_parts := ls_line.fields()
	if ls_line_parts.len < 4 {
		return none
	}

	item_type := ls_line_parts[1]
	item_size := ls_line_parts[3]
	item_path := ls_line_parts[4]

	item_name := item_path.after('/')
	if item_name == '' {
		return none
	}

	mut parent_path := os.dir(item_path)
	if parent_path == item_name {
		parent_path = ''
	}

	if item_name.contains('"\\') {
		// Unqoute octal UTF-8 strings
	}

	return File{
		name:               item_name
		parent_path:        parent_path
		repo_id:            r.id
		branch:             branch
		is_dir:             item_type == 'tree'
		size:               if item_type == 'blob' { item_size.int() } else { 0 }
		is_size_calculated: item_type == 'blob'
	}
}

pub fn (r &Repo) parse_top_file_line(line string, branch string) ?File {
	tab_pos := line.index('\t') or { return none }
	meta := line[..tab_pos]
	item_path := line[tab_pos + 1..]
	meta_parts := meta.fields()
	if meta_parts.len < 4 || meta_parts[1] != 'blob' {
		return none
	}

	item_name := item_path.after('/')
	if item_name == '' {
		return none
	}

	parent_path_raw := os.dir(item_path)
	parent_path := if parent_path_raw == '.' { '' } else { parent_path_raw }

	return File{
		name:               item_name
		parent_path:        parent_path
		repo_id:            r.id
		branch:             branch
		is_dir:             false
		size:               meta_parts[3].int()
		is_size_calculated: true
	}
}

pub fn (r &Repo) top_files(branch string, limit int) []File {
	git_result := git.Git.exec_in_dir(r.git_dir, ['ls-tree', '-r', '--full-name', '--long', branch])
	if git_result.exit_code != 0 {
		eprintln('git ls-tree top files error: ${git_result.output}')
		return []File{}
	}

	mut files := []File{}
	for line in git_result.output.split_into_lines() {
		file := r.parse_top_file_line(line, branch) or { continue }
		files << file
	}

	files.sort(b.size < a.size)
	if files.len > limit {
		return files[..limit]
	}

	return files
}

pub fn (r &Repo) calculate_child_folder_sizes(branch string, path string, dir_names []string) map[string]int {
	mut sizes := map[string]int{}
	for dir_name in dir_names {
		sizes[dir_name] = 0
	}
	if dir_names.len == 0 {
		return sizes
	}

	normalized_path := normalize_tree_path(path)
	mut args := ['ls-tree', '-r', '--full-name', '--long', branch]
	if normalized_path != '' {
		args << '--'
		args << normalized_path
	}

	result := git.Git.exec_in_dir(r.git_dir, args)
	if result.exit_code != 0 {
		eprintln('git ls-tree error while calculating folder sizes: ${result.output}')
		return sizes
	}

	prefix := if normalized_path == '' { '' } else { '${normalized_path}/' }
	for line in result.output.split_into_lines() {
		tab_pos := line.index('\t') or { continue }
		meta := line[..tab_pos]
		item_path := line[tab_pos + 1..]
		meta_parts := meta.fields()
		if meta_parts.len < 4 || meta_parts[1] != 'blob' {
			continue
		}

		mut relative_path := item_path
		if prefix != '' {
			if !item_path.starts_with(prefix) {
				continue
			}
			relative_path = item_path[prefix.len..]
		}

		slash_pos := relative_path.index('/') or { continue }
		child_dir := relative_path[..slash_pos]
		if child_dir !in sizes {
			continue
		}

		sizes[child_dir] = sizes[child_dir] + meta_parts[3].int()
	}

	return sizes
}

pub fn normalize_tree_path(path string) string {
	return path.trim_string_left('/').trim_string_right('/')
}

pub fn (r Repo) get_last_branch_commit_hash(branch_name string) string {
	git_result := git.Git.exec_in_dir(r.git_dir,
		['log', '-n', '1', branch_name, '--pretty=format:%h'])
	git_output := git_result.output

	if git_result.exit_code != 0 {
		eprintln('git log error: ${git_output}')
	}

	return git_output
}

pub fn (r Repo) git_advertise(service string) string {
	git_result := git.Git.exec([service, '--stateless-rpc', '--advertise-refs', r.git_dir])
	git_output := git_result.output

	if git_result.exit_code != 0 {
		eprintln('git ${service} error: ${git_output}')
	}

	return git_output
}

// TODO: return ?string
pub fn (r &Repo) git(command string) string {
	if command.contains('&') || command.contains(';') {
		return ''
	}
	println('git(): "${command}"')

	command_with_path := '-C ${r.git_dir} ${command}'

	command_result := git.Git.exec_in_dir_command(r.git_dir, command)
	command_exit_code := command_result.exit_code
	if command_exit_code != 0 {
		println('git error ${command_with_path} with ${command_exit_code} exit code out=${command_result.output}')

		return ''
	}

	return command_result.output.trim_space()
}

pub fn (r Repo) archive_tag(tag string, path string, format ArchiveFormat) {
	// TODO: check tag name before running command
	r.git('archive ${tag} --format=${format} --output="${path}"')
}

pub fn (r Repo) get_commit_patch(commit_hash string) ?string {
	patch := r.git('format-patch --stdout -1 ${commit_hash}')

	if patch == '' {
		return none
	}

	return patch
}

pub fn (r Repo) git_smart(service string, input string) string {
	git_path := git.get_git_executable_path() or { 'git' }
	real_repository_path := os.real_path(r.git_dir)

	mut process := os.new_process(git_path)
	process.set_args([service, '--stateless-rpc', real_repository_path])

	process.set_redirect_stdio()
	process.run()
	process.stdin_write(input)
	process.stdin_write('\n')

	output := process.stdout_slurp()
	errors := process.stderr_slurp()

	process.wait()
	process.close()

	if errors.len > 0 {
		eprintln('git ${service} error: ${errors}')

		return ''
	}

	return output
}

pub fn (r &Repo) read_file(branch string, path string) string {
	valid_path := path.trim_string_left('/')

	println('read_file() path=${valid_path}')
	t := time.now()
	// s := r.git('--no-pager show ${branch}:${valid_path}')

	s := git.Git.show_file_blob(r.git_dir, branch, valid_path) or { '' }
	println(time.since(t))
	println(':)')
	return s
}

fn (mut r Repo) clone() {
	eprintln('R CLONE')
	clone_result := git.Git.clone(r.clone_url, r.git_dir)
	clone_exit_code := clone_result.exit_code

	if clone_exit_code != 0 {
		r.status = .clone_failed
		println('git clone failed with exit code ${clone_exit_code}')
		return
	}

	r.status = .done
	eprintln('clone done')
}

pub enum RepoStatus {
	done         = 0
	caching      = 1
	clone_failed = 2
	cloning      = 3
}

pub struct LangStat {
pub:
	id          int    @[primary; sql: serial]
	repo_id     int    @[unique: 'langstat']
	name        string @[unique: 'langstat']
	lines_count int
	pct         int // out of 1000
	color       string
}

pub fn (l &LangStat) pct_html() veb.RawHtml {
	x := f64(l.pct) / 10.0
	sloc := if l.lines_count < 1000 {
		l.lines_count.str()
	} else {
		(l.lines_count / 1000).str() + 'k'
	}

	return '<span>${x}%</span> <span class=lang-stat-loc>${sloc} loc</span>'
}

pub enum ArchiveFormat {
	zip
	tar
}

pub fn (f ArchiveFormat) str() string {
	return match f {
		.zip { 'zip' }
		.tar { 'tar' }
	}
}