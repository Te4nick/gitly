module model

import time

pub struct Activity {
pub mut:
	id         int @[primary; sql: serial]
	user_id    int
	name       string
	created_at time.Time
}