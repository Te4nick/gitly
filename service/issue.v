// Copyright (c) 2019-2021 Alexander Medvednikov. All rights reserved.
// Use of this source code is governed by a GPL license that can be found in the LICENSE file.
module handler

import model {Issue, IssueStatus, Label}
import store {GitlyDb}
import time


pub struct IssueService {
	db GitlyDb
}


fn (mut s IssueService) add_issue(repo_id int, author_id int, title string, text string) ! {
	issue := Issue{
		title:      title
		text:       text
		repo_id:    repo_id
		author_id:  author_id
		created_at: int(time.now().unix())
	}

	sql s.db {
		insert issue into Issue
	}!
}

fn (mut s IssueService) find_issue_by_id(issue_id int) ?Issue {
	issues := sql s.db {
		select from Issue where id == issue_id limit 1
	} or { []Issue{} }
	if issues.len == 0 {
		return none
	}
	return issues.first()
}

fn (mut s IssueService) find_repo_issues_as_page(repo_id int, page int) []Issue {
	off := page * 35 // TODO: remake into limit_offset with paging in handler
	return sql s.db {
		select from Issue where repo_id == repo_id && is_pr == false limit 35 offset off
	} or { []Issue{} }
}

fn (mut s IssueService) get_repo_issue_count(repo_id int) int {
	return sql s.db {
		select count from Issue where repo_id == repo_id
	} or { 0 }
}

fn (mut s IssueService) find_user_issues(user_id int) []Issue {
	return sql s.db {
		select from Issue where author_id == user_id && is_pr == false
	} or { []Issue{} }
}

fn (mut s IssueService) delete_repo_issues(repo_id int) ! {
	sql s.db {
		delete from Issue where repo_id == repo_id
	}!
}

fn (mut s IssueService) increment_issue_comments(id int) ! {
	sql s.db {
		update Issue set comments_count = comments_count + 1 where id == id
	}!
}
