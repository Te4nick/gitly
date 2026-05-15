// Copyright (c) 2019-2021 Alexander Medvednikov. All rights reserved.
// Use of this source code is governed by a GPL license that can be found in the LICENSE file.
module service

import model {Commit, Change}
import store {GitlyDb}

pub struct CommitService {
	db GitlyDb
}

pub fn new_commit_service(db GitlyDb) CommitService {
	return CommitService{db: db}
}

fn (mut s CommitService) commit_exists(repo_id int, branch_id int, hash string) bool {
	count := sql s.db {
		select count from Commit where repo_id == repo_id && branch_id == branch_id && hash == hash
	} or { 0 }
	return count > 0
}

fn (mut s CommitService) add_commit(repo_id int, branch_id int, last_hash string, author string, author_id int, message string, date int) ! {
	new_commit := Commit{
		author_id:  author_id
		author:     author
		hash:       last_hash
		created_at: date
		repo_id:    repo_id
		branch_id:  branch_id
		message:    message
	}

	sql s.db {
		insert new_commit into Commit
	}!
}

fn (mut s CommitService) find_repo_commits_as_page(repo_id int, branch_id int, offset int) []Commit {
	return sql s.db {
		select from Commit where repo_id == repo_id && branch_id == branch_id order by created_at desc limit 35 offset offset
	} or { []Commit{} }
}

fn (mut s CommitService) get_repo_commit_count(repo_id int, branch_id int) int {
	return sql s.db {
		select count from Commit where repo_id == repo_id && branch_id == branch_id
	} or { 0 }
}

fn (mut s CommitService) find_repo_commit_by_hash(repo_id int, hash string) Commit {
	commits := sql s.db {
		select from Commit where repo_id == repo_id && hash == hash
	} or { []Commit{} }
	if commits.len == 1 {
		return commits[0]
	}
	return Commit{}
}

fn (mut s CommitService) find_repo_last_commit(repo_id int, branch_id int) Commit {
	commits := sql s.db {
		select from Commit where repo_id == repo_id && branch_id == branch_id order by created_at desc limit 1
	} or { []Commit{} }

	if commits.len == 0 {
		return Commit{}
	}

	return commits.first()
}
