module service

import time
import git
import model {Branch, Repo, User}
import store {GitlyDb}

pub struct BranchService {
	UserService
	db GitlyDb
}


pub fn (mut s BranchService) fetch_branches(repo Repo) ! {
	branches_output := repo.git('branch -a')

	for branch_output in branches_output.split_into_lines() {
		branch_name := git.parse_git_branch_output(branch_output)

		s.fetch_branch(repo, branch_name)!
	}
}

fn (mut s BranchService) fetch_branch(repo Repo, branch_name string) ! {
	last_commit_hash := repo.get_last_branch_commit_hash(branch_name)

	branch_data :=
		repo.git('log ${branch_name} -1 --pretty="%aE${log_field_separator}%cD" ${last_commit_hash}')
	log_parts := branch_data.split(log_field_separator)

	author_email := log_parts[0]
	committed_at := time.parse_rfc2822(log_parts[1]) or {
		// app.info('Error: ${err}') // TODO: reimplement

		return
	}

	user := s.get_user_by_email(author_email) or {
		User{
			username: author_email
		}
	}

	s.create_branch_or_update(repo.id, branch_name, user.username, last_commit_hash,
		int(committed_at.unix()))!
}

pub fn (mut s BranchService) create_branch_or_update(repository_id int, branch_name string, author string, hash string, date int) ! {
	branches := sql s.db {
		select from Branch where repo_id == repository_id && name == branch_name limit 1
	} or { []Branch{} }

	// app.debug("branches: ${branches}")

	if branches.len != 0 {
		branch := branches.first()
		s.update_branch(branch.id, author, hash, date)!

		return
	}

	new_branch := Branch{
		repo_id: repository_id
		name:    branch_name
		author:  author
		hash:    hash
		date:    date
	}

	// app.debug('inserting branch: ${new_branch}')

	sql s.db {
		insert new_branch into Branch
	}!
}

pub fn (mut s BranchService) update_branch(branch_id int, author string, hash string, date int) ! {
	sql s.db {
		update Branch set author = author, hash = hash, date = date where id == branch_id
	}!
}

pub fn (mut s BranchService) find_repo_branch_by_name(repo_id int, name string) Branch {
	branches := sql s.db {
		select from Branch where name == name && repo_id == repo_id limit 1
	} or { []Branch{} }

	if branches.len == 0 {
		return Branch{}
	}

	return branches.first()
}

pub fn (mut s BranchService) find_repo_branch_by_id(repo_id int, id int) Branch {
	branches := sql s.db {
		select from Branch where id == id && repo_id == repo_id limit 1
	} or { []Branch{} }

	if branches.len == 0 {
		return Branch{}
	}

	return branches.first()
}

pub fn (s BranchService) get_all_repo_branches(repo_id int) []Branch {
	return sql s.db {
		select from Branch where repo_id == repo_id order by date desc
	} or { []Branch{} }
}

pub fn (mut s BranchService) get_count_repo_branches(repo_id int) int {
	return sql s.db {
		select count from Branch where repo_id == repo_id
	} or { 0 }
}

pub fn (mut s BranchService) contains_repo_branch(repo_id int, name string) bool {
	count := sql s.db {
		select count from Branch where repo_id == repo_id && name == name
	} or { 0 }

	return count == 1
}

pub fn (mut s BranchService) delete_repo_branches(repo_id int) ! {
	sql s.db {
		delete from Branch where repo_id == repo_id
	}!
}
