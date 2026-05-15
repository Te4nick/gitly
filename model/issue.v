module model

import time

pub struct Issue {
pub:
	id int @[primary; sql: serial]
pub mut:
	author_id      int
	repo_id        int
	is_pr          bool
	assigned       []int @[skip]
	labels         []int @[skip]
	comments_count int
	title          string
	text           string
	created_at     int
	status         IssueStatus @[skip]
	linked_issues  []int       @[skip]
	repo_author    string      @[skip]
	repo_name      string      @[skip]
}

pub fn (i &Issue) relative_time() string {
	return time.unix(i.created_at).relative()
}

pub enum IssueStatus {
	open   = 0
	closed = 1
}

pub struct Label {
pub:
	id    int
	name  string
	color string
}
