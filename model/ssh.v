module model

import time

pub struct SshKey {
pub:
	id         int    @[primary; sql: serial]
	user_id    int    @[unique: 'ssh_key']
	title      string @[unique: 'ssh_key']
	key        string
	created_at time.Time
}