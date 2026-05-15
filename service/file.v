module service

import model {File}
import os
import store {GitlyDb}

pub struct FileService {
	db GitlyDb
}

pub fn new_file_service(db GitlyDb) FileService {
	return FileService{db: db}
}

pub fn calculate_lines_of_code(source string) (int, int) {
	lines := source.split_into_lines()
	loc := lines.len
	sloc := lines.filter(it.trim_space() != '').len

	return loc, sloc
}

pub fn (mut s FileService) add_file(file File) ! {
	sql s.db {
		insert file into File
	}!
}

pub fn (mut s FileService) find_repository_items(repo_id int, branch string, parent_path string) []File {
	valid_parent_path := if parent_path == '' { '.' } else { parent_path }

	items := sql s.db {
		select from File where repo_id == repo_id && parent_path == valid_parent_path
		&& branch == branch
	} or { []File{} }

	return items
}

pub fn (mut s FileService) find_repo_file_by_path(repo_id int, item_branch string, path string) ?File {
	mut valid_parent_path := os.dir(path)
	item_name := path.after('/')

	if valid_parent_path == '' || valid_parent_path == '/' {
		valid_parent_path = '.'
	}

	// app.info('find file repo_id=${repo_id} parent_path = ${valid_parent_path} branch=${item_branch} name=${item_branch}') // TODO: reimplement?

	files := sql s.db {
		select from File where repo_id == repo_id && parent_path == valid_parent_path
		&& branch == item_branch && name == item_name limit 1
	} or { []File{} }

	if files.len == 0 {
		return none
	}

	return files.first()
}

pub fn (mut s FileService) delete_repository_files(repository_id int) ! {
	sql s.db {
		delete from File where repo_id == repository_id
	}!
}

pub fn (mut s FileService) delete_repository_files_in_branch(repository_id int, branch_name string) ! {
	sql s.db {
		delete from File where repo_id == repository_id && branch == branch_name
	}!
}

pub fn (mut s FileService) delete_repo_folder(path string) {
	os.rmdir_all(os.real_path(path)) or { panic(err) }
}
