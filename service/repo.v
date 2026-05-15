// Copyright (c) 2019-2021 Alexander Medvednikov. All rights reserved.
// Use of this source code is governed by a GPL license that can be found in the LICENSE file.
module service

import veb
import os
import time
import git
import highlight
import model {Repo, RepoStatus, LangStat, File, User, Commit}
import store
import validation


// log_field_separator is declared as constant in case we need to change it later
const max_git_res_size = 1000
const log_field_separator = '\x7F'
const ignored_folder = ['thirdparty']

pub struct RepoService {
	CommitService
	BranchService
	FileService
	IssueService
	ReleaseService
	UserService
	WatchService
	db store.GitlyDb
}

fn (mut s RepoService) save_repo(repo Repo) ! {
	id := repo.id
	desc := repo.description
	views_count := repo.views_count
	webhook_secret := repo.webhook_secret
	tags_count := repo.tags_count
	is_public := repo.is_public // if repo.is_public { 1 } else { 0 } // SQLITE hack
	open_issues_count := repo.nr_open_issues
	open_prs_count := repo.nr_open_prs
	branches_count := repo.nr_branches
	releases_count := repo.nr_releases
	stars_count := repo.nr_stars
	contributors_count := repo.nr_contributors

	// XTODO sql update all fields automatically
	// repo.update()

	sql s.db {
		update Repo set description = desc, views_count = views_count, is_public = is_public,
		webhook_secret = webhook_secret, tags_count = tags_count, nr_open_issues = open_issues_count,
		nr_open_prs = open_prs_count, nr_releases = releases_count, nr_contributors = contributors_count,
		nr_stars = stars_count, nr_branches = branches_count where id == id
	}!
}

fn (s RepoService) find_repo_by_name_and_user_id(repo_name string, user_id int) ?Repo {
	repos := sql s.db {
		select from Repo where name == repo_name && user_id == user_id limit 1
	} or { return none }

	if repos.len == 0 {
		return none
	}

	mut repo := repos[0]
	repo.lang_stats = s.find_repo_lang_stats(repo.id)
	println('GIT DIR = ${repo.git_dir}')

	return repo
}

fn (s RepoService) find_repo_by_name_and_username(repo_name string, username string) ?Repo {
	user := s.get_user_by_username(username) or { return none }

	return s.find_repo_by_name_and_user_id(repo_name, user.id)
}

fn (mut s RepoService) get_count_user_repos(user_id int) int {
	return sql s.db {
		select count from Repo where user_id == user_id
	} or { 0 }
}

fn (mut s RepoService) find_user_repos(user_id int) []Repo {
	return sql s.db {
		select from Repo where user_id == user_id
	} or { []Repo{} }
}

fn (mut s RepoService) find_user_public_repos(user_id int) []Repo {
	return sql s.db {
		select from Repo where user_id == user_id && is_public == true
	} or { []Repo{} }
}

fn (mut s RepoService) search_public_repos(query string) []Repo {
	repo_rows := store.db_exec_values(s.db,
		'select id, name, user_id, description, stars_count from ${store.sql_table('Repo')} where is_public is true and name like ${store.sql_like_pattern(query)}') or {
		return []
	}

	mut repos := []Repo{}

	for row in repo_rows {
		user_id := row[2].int()
		user := s.get_user_by_id(user_id) or { User{} }

		repos << Repo{
			id:          row[0].int()
			name:        row[1]
			user_name:   user.username
			description: row[3]
			nr_stars:    row[4].int()
		}
	}

	return repos
}

fn (mut s RepoService) find_repo_by_id(repo_id int) ?Repo {
	repos := sql s.db {
		select from Repo where id == repo_id
	} or { []Repo{} }

	if repos.len == 0 {
		return none
	}

	mut repo := repos.first()
	repo.lang_stats = s.find_repo_lang_stats(repo.id)

	return repo
}

fn (mut s RepoService) increment_repo_views(repo_id int) ! {
	sql s.db {
		update Repo set views_count = views_count + 1 where id == repo_id
	}!
}

fn (mut s RepoService) increment_repo_stars(repo_id int) ! {
	sql s.db {
		update Repo set nr_stars = nr_stars + 1 where id == repo_id
	}!
}

fn (mut s RepoService) decrement_repo_stars(repo_id int) ! {
	sql s.db {
		update Repo set nr_stars = nr_stars - 1 where id == repo_id
	}!
}

fn (mut s RepoService) increment_file_views(file_id int) ! {
	sql s.db {
		update File set views_count = views_count + 1 where id == file_id
	}!
}

fn (mut s RepoService) set_repo_webhook_secret(repo_id int, secret string) ! {
	sql s.db {
		update Repo set webhook_secret = secret where id == repo_id
	}!
}

fn (mut s RepoService) set_repo_status(repo_id int, status RepoStatus) ! {
	sql s.db {
		update Repo set status = status where id == repo_id
	}!
}

fn (mut s RepoService) increment_repo_issues(repo_id int) ! {
	sql s.db {
		update Repo set nr_open_issues = nr_open_issues + 1 where id == repo_id
	}!
}

fn (mut s RepoService) get_count_repo() int {
	return sql s.db {
		select count from Repo
	} or { 0 }
}

fn (mut s RepoService) add_repo(repo Repo) ! {
	sql s.db {
		insert repo into Repo
	}!
}

fn (mut s RepoService) delete_repository(id int, path string, name string) ! {
	sql s.db {
		delete from Repo where id == id
	}!
	// app.info('Removed repo entry (${id}, ${name})') // TODO: reimplement? and below

	sql s.db {
		delete from Commit where repo_id == id
	}!

	//app.info('Removed repo commits (${id}, ${name})')
	s.delete_repo_issues(id)!
	//app.info('Removed repo issues (${id}, ${name})')

	s.delete_repo_branches(id)!
	//app.info('Removed repo branches (${id}, ${name})')

	s.delete_repo_releases(id)!
	//app.info('Removed repo releases (${id}, ${name})')

	s.delete_repository_files(id)!
	//app.info('Removed repo files (${id}, ${name})')

	s.delete_repo_folder(path)
	//app.info('Removed repo folder (${id}, ${name})')

	s.delete_repo_ci_statuses(id) or {}
	//app.info('Removed repo CI statuses (${id}, ${name})')
}

fn (mut s RepoService) move_repo_to_user(repo_id int, user_id int, user_name string) ! {
	sql s.db {
		update Repo set user_id = user_id, user_name = user_name where id == repo_id
	}!
}

fn (mut s RepoService) user_has_repo(user_id int, repo_name string) bool {
	count := sql s.db {
		select count from Repo where user_id == user_id && name == repo_name
	} or { 0 }
	return count >= 0
}

fn (mut s RepoService) update_repo_from_fs(mut repo Repo) ! {
	println('UPDATE REPO FROM FS')
	repo_id := repo.id

	s.db.exec('BEGIN TRANSACTION')!

	s.analyze_lang(repo)!

	// app.info(repo.nr_contributors.str()) // TODO: reimplement
	s.fetch_branches(repo)!

	branches_output := repo.git('branch -a')
	println('b output=${branches_output}')

	for branch_output in branches_output.split_into_lines() {
		branch_name := git.parse_git_branch_output(branch_output)

		s.update_repo_branch_from_fs(mut repo, branch_name)!
	}

	repo.nr_contributors = s.get_count_repo_contributors(repo_id)!
	repo.nr_branches = s.get_count_repo_branches(repo_id)

	// TODO: TEMPORARY - UNTIL WE GET PERSISTENT RELEASE INFO
	for tag in s.get_all_repo_tags(repo_id) {
		app.add_release(tag.id, repo_id, time.unix(tag.created_at), tag.message)!

		repo.nr_releases++
	}

	s.save_repo(repo)!
	s.db.exec('END TRANSACTION')!
	// app.info('Repo updated')
}

// fn (mut app App) update_repo_branch_from_fs(mut ctx Context, mut repo Repo, branch_name string) ! {
fn (mut s RepoService) update_repo_branch_from_fs(mut repo Repo, branch_name string) ! {
	repo_id := repo.id
	branch := s.find_repo_branch_by_name(repo.id, branch_name)

	if branch.id == 0 {
		return
	}

	data :=
		repo.git('--no-pager log ${branch_name} --abbrev-commit --abbrev=7 --pretty="%h${log_field_separator}%aE${log_field_separator}%cD${log_field_separator}%s${log_field_separator}%aN"')

	for line in data.split_into_lines() {
		args := line.split(log_field_separator)

		if args.len > 4 {
			commit_hash := args[0]
			commit_author_email := args[1]
			commit_message := args[3]
			commit_author := args[4]
			mut commit_author_id := 0

			// git log outputs newest commits first; if this commit already
			// exists, all subsequent (older) commits do too — stop early.
			if s.commit_exists(repo_id, branch.id, commit_hash) {
				break
			}

			commit_date := time.parse_rfc2822(args[2]) or {
				//app.info('Error: ${err}')
				return
			}

			user := s.get_user_by_email(commit_author_email) or { User{} }

			if user.id > 0 {
				s.add_contributor(user.id, repo_id)!

				commit_author_id = user.id
			}

			s.add_commit(repo_id, branch.id, commit_hash, commit_author, commit_author_id,
				commit_message, int(commit_date.unix()))!
		}
	}
}

fn (mut s RepoService) update_repo_from_remote(mut repo Repo) ! {
	repo_id := repo.id

	repo.git('fetch --all')
	repo.git('pull --all')

	s.db.exec('BEGIN TRANSACTION')!

	repo.analyze_lang(app)!

	app.info(repo.nr_contributors.str())
	app.fetch_branches(repo)!
	app.fetch_tags(repo)!

	branches_output := repo.git('branch -a')

	for branch_output in branches_output.split_into_lines() {
		branch_name := git.parse_git_branch_output(branch_output)

		app.update_repo_branch_from_fs(mut repo, branch_name)!
	}

	for tag in app.get_all_repo_tags(repo_id) {
		app.add_release(tag.id, repo_id, time.unix(tag.created_at), tag.message)!
		repo.nr_releases++
	}

	repo.nr_contributors = app.get_count_repo_contributors(repo_id)!
	repo.nr_branches = app.get_count_repo_branches(repo_id)

	s.save_repo(repo)!
	s.db.exec('END TRANSACTION')!
	//app.info('Repo updated')
}

fn (mut s RepoService) update_repo_branch_data(mut repo Repo, branch_name string) ! {
	repo_id := repo.id
	branch := s.find_repo_branch_by_name(repo.id, branch_name)

	if branch.id == 0 {
		return
	}

	data :=
		repo.git('--no-pager log ${branch_name} --abbrev-commit --abbrev=7 --pretty="%h${log_field_separator}%aE${log_field_separator}%cD${log_field_separator}%s${log_field_separator}%aN"')

	for line in data.split_into_lines() {
		args := line.split(log_field_separator)

		if args.len > 4 {
			commit_hash := args[0]
			commit_author_email := args[1]
			commit_message := args[3]
			commit_author := args[4]
			mut commit_author_id := 0

			if s.commit_exists(repo_id, branch.id, commit_hash) {
				break
			}

			commit_date := time.parse_rfc2822(args[2]) or {
				//app.info('Error: ${err}')
				return
			}

			user := s.get_user_by_email(commit_author_email) or { User{} }

			if user.id > 0 {
				s.add_contributor(user.id, repo_id)!

				commit_author_id = user.id
			}

			s.add_commit(repo_id, branch.id, commit_hash, commit_author, commit_author_id,
				commit_message, int(commit_date.unix()))!
		}
	}
}

// TODO: tags and other stuff
fn (mut s RepoService) update_repo_after_push(repo_id int, branch_name string) ! {
	mut repo := s.find_repo_by_id(repo_id) or { return }

	s.update_repo_from_fs(mut repo)!
	s.delete_repository_files_in_branch(repo_id, branch_name)!
}

fn (mut s RepoService) analyze_lang(r &Repo) ! {
	file_paths := s.get_all_file_paths(r)

	mut all_size := 0
	mut lang_stats := map[string]int{}
	mut langs := map[string]highlight.Lang{}

	for file_path in file_paths {
		lang := highlight.extension_to_lang(file_path.split('.').last()) or { continue }
		file_content := r.read_file(r.primary_branch, file_path)
		lines := file_content.split_into_lines()
		size := calc_lines_of_code(lines, lang)

		if lang.name !in lang_stats {
			lang_stats[lang.name] = 0
		}
		if lang.name !in langs {
			langs[lang.name] = lang
		}

		lang_stats[lang.name] = lang_stats[lang.name] + size
		all_size += size
	}

	mut d_lang_stats := []LangStat{}
	mut tmp_a := []int{}

	for lang, amount in lang_stats {
		// skip 0 lines of code
		if amount == 0 {
			continue
		}

		mut tmp := f32(amount) / f32(all_size)
		tmp *= 1000
		pct := int(tmp)
		if pct !in tmp_a {
			tmp_a << pct
		}
		lang_data := langs[lang]
		d_lang_stats << LangStat{
			repo_id:     r.id
			name:        lang_data.name
			pct:         pct
			color:       lang_data.color
			lines_count: amount
		}
	}

	tmp_a.sort()
	tmp_a = tmp_a.reverse()

	mut tmp_stats := []LangStat{}

	for pct in tmp_a {
		all_with_ptc := r.lang_stats.filter(it.pct == pct)
		for lang in all_with_ptc {
			tmp_stats << lang
		}
	}

	s.remove_repo_lang_stats(r.id)!

	for lang_stat in d_lang_stats {
		s.add_lang_stat(lang_stat)!
	}
}

fn calc_lines_of_code(lines []string, lang highlight.Lang) int {
	mut size := 0
	lcomment := lang.line_comments
	mut mlcomment_start := ''
	mut mlcomment_end := ''
	if lang.mline_comments.len >= 2 {
		mlcomment_start = lang.mline_comments[0]
		mlcomment_end = lang.mline_comments[1]
	}
	mut in_comment := false
	for line in lines {
		tmp_line := line.trim_space()
		if tmp_line.len > 0 { // Empty line ignored
			if tmp_line.contains(mlcomment_start) {
				in_comment = true
				if tmp_line.starts_with(mlcomment_start) {
					continue
				}
			}
			if tmp_line.contains(mlcomment_end) {
				if in_comment {
					in_comment = false
				}
				if tmp_line.ends_with(mlcomment_end) {
					continue
				}
			}
			if in_comment {
				continue
			}
			if tmp_line.contains(lcomment) {
				if tmp_line.starts_with(lcomment) {
					continue
				}
			}
			size++
		}
	}
	return size
}

fn (mut s RepoService) get_all_file_paths(r &Repo) []string {
	ls_output := r.git('ls-tree -r ${r.primary_branch} --name-only')
	mut file_paths := []string{}

	for file_path in ls_output.split_into_lines() {
		path_parts := file_path.split('/')
		has_ignored_folders := path_parts.any(ignored_folder.contains(it))

		if has_ignored_folders {
			continue
		}

		file_paths << file_path
	}

	return file_paths
}

// Fetches all files via `git ls-tree` and saves them in db
fn (mut s RepoService) cache_repository_items(mut r Repo, branch string, path string) ![]File {
	if r.status == .caching {
		// app.info('`${r.name}` is being cached already') // TODO: reimplement
		return []
	}

	mut repository_ls := ''
	if path == '.' {
		r.status = .caching

		defer {
			r.status = .done
		}
	} else {
		directory_path := if path == '' { path } else { '${path}/' }
		format := '%(objectmode) %(objecttype) %(objectname) %(objectsize) %(path)'
		repository_ls =
			r.git('ls-tree --full-name --format="${format}" ${branch} ${directory_path}')
	}

	// mode type name path
	item_info_lines := repository_ls.split('\n')

	mut dirs := []File{} // dirs first
	mut files := []File{}

	s.db.exec('BEGIN TRANSACTION')!

	for item_info in item_info_lines {
		is_item_info_empty := validation.is_string_empty(item_info)

		if is_item_info_empty {
			continue
		}

		file := r.parse_ls(item_info, branch) or {
			// app.warn('failed to parse ${item_info}')
			continue
		}

		if file.is_dir {
			dirs << file

			s.add_file(file)!
		} else {
			files << file
		}
	}

	dirs << files
	for file in files {
		s.add_file(file)!
	}

	s.db.exec('END TRANSACTION')!

	return dirs
}

// fetches last message and last time for each file
// this is slow, so it's run in the background thread
fn (mut s RepoService) slow_fetch_files_info(mut repo Repo, branch string, path string) ! {
	files := s.find_repository_items(repo.id, branch, path)

	for i in 0 .. files.len {
		if files[i].last_msg != '' {
			//app.warn('skipping ${files[i].name}')
			continue
		}

		s.fetch_file_info(repo, files[i])!
	}
}

fn (mut s RepoService) slow_fetch_folder_sizes(mut repo Repo, branch string, path string) ! {
	files := s.find_repository_items(repo.id, branch, path)
	dirs := files.filter(it.is_dir && !it.is_size_calculated)
	if dirs.len == 0 {
		return
	}

	dir_names := dirs.map(it.name)
	sizes := repo.calculate_child_folder_sizes(branch, path, dir_names)

	for dir in dirs {
		size := sizes[dir.name] or { 0 }
		s.update_file_size(dir.id, size, true)!
	}
}



fn first_line(s string) string {
	pos := s.index('\n') or { return s }
	return s[..pos]
}

fn (mut s RepoService) fetch_file_info(r &Repo, file &File) ! {
	logs := r.git('log -n1 --format=%B___%at___%H___%an ${file.branch} -- ${file.full_path()}')
	vals := logs.split('___')
	if vals.len < 3 {
		return
	}
	last_msg := first_line(vals[0])
	last_time := vals[1].int()
	last_hash := vals[2]

	file_id := file.id
	sql s.db {
		update File set last_msg = last_msg, last_time = last_time, last_hash = last_hash
		where id == file_id
	}!
}

fn (mut s RepoService) update_file_size(file_id int, size int, is_size_calculated bool) ! {
	sql s.db {
		update File set size = size, is_size_calculated = is_size_calculated where id == file_id
	}!
}

fn (mut s RepoService) update_repo_primary_branch(repo_id int, branch string) ! {
	sql s.db {
		update Repo set primary_branch = branch where id == repo_id
	}!
}

fn find_readme_file(items []File) ?File {
	files := items.filter(it.name.to_lower().starts_with('readme.') && it.name.split('.').len == 2
		&& !it.is_dir)

	if files.len == 0 {
		return none
	}

	// firstly search markdown files
	readme_md_files := files.filter(it.name.to_lower().ends_with('.md'))

	if readme_md_files.len > 0 {
		return readme_md_files.first()
	}

	// and then txt files
	readme_txt_files := files.filter(it.name.to_lower().ends_with('.txt'))

	if readme_txt_files.len > 0 {
		return readme_txt_files.first()
	}

	return none
}

fn find_license_file(items []File) ?File {
	// List of common license file names
	license_common_files := ['license', 'license.md', 'license.txt', 'licence', 'licence.md',
		'licence.txt']

	files := items.filter(license_common_files.contains(it.name.to_lower()))

	if files.len == 0 {
		return none
	}
	return files[0]
}

fn (mut s RepoService) has_user_repo_read_access(ctx Context, user_id int, repo_id int) bool {
	if !ctx.logged_in {
		return false
	}
	repo := app.find_repo_by_id(repo_id) or { return false }
	if repo.is_public {
		return true
	}
	is_repo_owner := repo.user_id == user_id
	if is_repo_owner {
		return true
	}
	return false
}

fn (mut s RepoService) has_user_repo_read_access_by_repo_name(ctx Context, user_id int, repo_owner_name string, repo_name string) bool {
	user := app.get_user_by_username(repo_owner_name) or { return false }
	repo := app.find_repo_by_name_and_user_id(repo_name, user.id) or { return false }
	return app.has_user_repo_read_access(ctx, user_id, repo.id)
}

fn (mut s RepoService) check_repo_owner(username string, repo_name string) bool {
	user := s.get_user_by_username(username) or { return false }
	repo := s.find_repo_by_name_and_user_id(repo_name, user.id) or { return false }
	return repo.user_id == user.id
}

fn (mut app App) format_commits_count(repo Repo, branch_name string) veb.RawHtml {
	branch := app.find_repo_branch_by_name(repo.id, branch_name)
	nr_commits := app.get_repo_commit_count(repo.id, branch.id)
	if nr_commits == 1 {
		return '<b>${nr_commits}</b> commit'
	}

	return '<b>${nr_commits}</b> commits'
}