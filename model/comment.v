module model

import time

pub struct Comment {
pub mut:
	id         int @[primary; sql: serial]
	author_id  int
	issue_id   int
	created_at int
	text       string
}

fn (c Comment) relative() string {
	return time.unix(c.created_at).relative()
}