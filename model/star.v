module model

pub struct Star {
pub:
	id      int @[primary; sql: serial]
	user_id int @[unique: 'repo_star']
	repo_id int @[unique: 'repo_star']
}