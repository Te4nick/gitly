module model

import time

pub struct User {
pub:
	id              int @[primary; sql: serial]
	full_name       string
	username        string @[unique]
	github_username string
	password        string
	salt            string
	created_at      time.Time
	is_github       bool
	is_registered   bool
	is_blocked      bool
	is_admin        bool
	oauth_state     string @[skip]
pub mut:
	// for github oauth XSRF protection
	namechanges_count    int
	last_namechange_time int
	posts_count          int
	last_post_time       int
	avatar               string
	emails               []Email @[skip]
	login_attempts       int
}

pub struct Email {
pub:
	id      int @[primary; sql: serial]
	user_id int
	email   string @[unique]
}

pub struct Contributor {
pub:
	id      int @[primary; sql: serial]
	user_id int @[unique: 'contributor']
	repo_id int @[unique: 'contributor']
}