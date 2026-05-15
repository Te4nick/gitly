module model

import time

pub struct Branch {
pub mut:
	id      int    @[primary; sql: serial]
	repo_id int    @[unique: 'branch']
	name    string @[unique: 'branch']
	author  string // author of latest commit on branch
	hash    string // hash of latest commit on branch
	date    int    // time of latest commit on branch
}

pub fn (branch Branch) relative() string {
	return time.unix(branch.date).relative()
}
