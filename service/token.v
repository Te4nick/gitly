// Copyright (c) 2019-2021 Alexander Medvednikov. All rights reserved.
// Use of this source code is governed by a GPL license that can be found in the LICENSE file.
module service

import model { Token }
import store { GitlyDb }
import rand


pub struct TokenService {
	db GitlyDb
}

pub fn new_token_service(db GitlyDb) TokenService {
	return TokenService{db: db}
}

pub fn (mut s TokenService) add_token(user_id int, ip string) !string {
	uuid := rand.uuid_v4()

	token := Token{
		user_id: user_id
		value:   uuid
		ip:      ip
	}

	sql s.db {
		insert token into Token
	}!

	return uuid
}

pub fn (mut s TokenService) get_token(value string) ?Token {
	tokens := sql s.db {
		select from Token where value == value limit 1
	} or { []Token{} }
	if tokens.len == 0 {
		return none
	}
	return tokens.first()
}

pub fn (mut s TokenService) delete_tokens(user_id int) ! {
	sql s.db {
		delete from Token where user_id == user_id
	}!
}
