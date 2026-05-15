module model

pub struct Tag {
pub:
	id      int @[primary; sql: serial]
	repo_id int @[unique: 'tag']
pub mut:
	name       string @[unique: 'tag']
	hash       string
	message    string
	user_id    int
	created_at int
}