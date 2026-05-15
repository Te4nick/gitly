module service

import model { SshKey }
import store {GitlyDb }
import time

pub struct SshService {
	db GitlyDb
}

pub fn new_ssh_service(db GitlyDb) SshService {
	return SshService{db: db}
}

pub fn (mut s SshService) add_ssh_key(user_id int, title string, key string) ! {
	ssh_keys := sql s.db {
		select from model.SshKey where user_id == user_id && title == title limit 1
	} or { [] }

	if ssh_keys.len != 0 {
		return error('SSH Key already exists')
	}

	new_ssh_key := SshKey{
		user_id:    user_id
		title:      title
		key:        key
		created_at: time.now()
	}

	sql s.db {
		insert new_ssh_key into model.SshKey
	}!
}

pub fn (mut s SshService) find_ssh_keys(user_id int) []SshKey {
	return sql s.db {
		select from model.SshKey where user_id == user_id
	} or { [] }
}

pub fn (mut s SshService) remove_ssh_key(user_id int, id int) ! {
	sql s.db {
		delete from model.SshKey where id == id && user_id == user_id
	}!
}
