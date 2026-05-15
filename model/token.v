module model

pub struct Token {
pub:
	id      int @[primary; sql: serial]
	user_id int
	value   string
	ip      string
}