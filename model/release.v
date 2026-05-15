module model

import time

pub struct Release {
pub:
	id      int @[primary; sql: serial]
	repo_id int @[unique: 'release']
pub mut:
	tag_id   int @[unique: 'release']
	notes    string
	tag_name string @[skip]
	tag_hash string @[skip]
	user     string @[skip]
	date     time.Time
}