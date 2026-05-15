module service

import crypto.sha256
import model { User, Email, Contributor, Repo }
import time
import os
import store


const default_avatar_name = 'default_avatar.png' // TODO: extract to common

pub struct UserService {
	TokenService
	ActivityService
	db store.GitlyDb
	repo_storage_path string
}

pub fn new_user_service(db store.GitlyDb, t TokenService, a ActivityService, repo_storage_path string) UserService {
	return UserService{t, a, db, repo_storage_path}
}

pub fn (mut s UserService) set_user_block_status(user_id int, status bool) ! {
	sql s.db {
		update User set is_blocked = status where id == user_id
	}!
}

pub fn (mut s UserService) set_user_admin_status(user_id int, status bool) ! {
	sql s.db {
		update User set is_admin = status where id == user_id
	}!
}

fn hash_password_with_salt(password string, salt string) string {
	salted_password := '${password}${salt}'

	return sha256.sum(salted_password.bytes()).hex().str()
}

fn compare_password_with_hash(password string, salt string, hashed string) bool {
	return hash_password_with_salt(password, salt) == hashed
}

pub fn (mut s UserService) register_user(username string, password string, salt string, emails []string, github bool, is_admin bool) !bool {
	mut user := s.get_user_by_username(username) or { User{} }

	if user.id != 0 && user.is_registered {
		// s.info('User ${username} already exists') // TODO: reimplement?
		return false
	}

	user = s.get_user_by_email(emails[0]) or { User{} }

	if user.id == 0 {
		user = User{
			username:        username
			password:        password
			salt:            salt
			created_at:      time.now()
			is_registered:   true
			is_github:       github
			github_username: username
			avatar:          default_avatar_name
			is_admin:        is_admin
		}

		s.add_user(user)!

		mut u := s.get_user_by_username(user.username) or {
			// app.info('User was not inserted') // TODO: reimplement?
			return false
		}

		if u.password != user.password || u.username != user.username {
			// app.info('User was not inserted') // TODO: reimplement?
			return false
		}

		s.add_activity(u.id, 'joined')!

		for email in emails {
			s.add_email(u.id, email)!
		}

		u.emails = s.find_user_emails(u.id)
	} else {
		// Update existing user
		if !github {
			s.create_user_dir(username)

			return true
		}

		if user.is_registered {
			sql s.db {
				update User set is_github = true where id == user.id
			}!
			return true
		}
	}
	s.create_user_dir(username)

	return true
}

fn (mut s UserService) create_user_dir(username string) { // TODO: extract from here
	user_path := '${s.repo_storage_path}/${username}'

	os.mkdir(user_path) or {
		// app.info('Failed to create ${user_path}') // TODO: reimplement?
		// app.info('Error: ${err}') // TODO: reimplement?
		return
	}
}

pub fn (mut s UserService) update_user_avatar(user_id int, filename_or_url string) ! {
	sql s.db {
		update User set avatar = filename_or_url where id == user_id
	}!
}

pub fn (mut s UserService) add_user(user User) ! {
	sql s.db {
		insert user into User
	}!
}

pub fn (mut s UserService) add_email(user_id int, email string) ! {
	user_email := Email{
		user_id: user_id
		email:   email
	}

	sql s.db {
		insert user_email into Email
	}!
}

pub fn (mut s UserService) add_contributor(user_id int, repo_id int) ! {
	if !s.contains_contributor(user_id, repo_id) {
		contributor := Contributor{
			user_id: user_id
			repo_id: repo_id
		}

		sql s.db {
			insert contributor into Contributor
		}!
	}
}

pub fn (s UserService) get_username_by_id(id int) ?string {
	users := sql s.db {
		select from User where id == id limit 1
	} or { [] }

	if users.len == 0 {
		return none
	}

	return users.first().username
}

pub fn (s UserService) get_user_by_username(value string) ?User {
	users := sql s.db {
		select from User where username == value limit 1
	} or { [] }

	if users.len == 0 {
		return none
	}

	mut user := users.first()
	emails := s.find_user_emails(user.id)
	user.emails = emails

	return user
}

pub fn (s UserService) get_user_by_id(id int) ?User {
	users := sql s.db {
		select from User where id == id
	} or { [] }

	if users.len == 0 {
		return none
	}

	mut user := users.first()
	emails := s.find_user_emails(user.id)
	user.emails = emails

	return user
}

pub fn (mut s UserService) get_user_by_github_username(name string) ?User {
	users := sql s.db {
		select from User where github_username == name limit 1
	} or { [] }

	if users.len == 0 {
		return none
	}

	mut user := users.first()
	emails := s.find_user_emails(user.id)
	user.emails = emails

	return user
}

pub fn (mut s UserService) get_user_by_email(value string) ?User {
	emails := sql s.db {
		select from Email where email == value
	} or { [] }

	if emails.len != 1 {
		return none
	}

	return s.get_user_by_id(emails[0].user_id)
}

pub fn (s UserService) find_user_emails(user_id int) []Email {
	emails := sql s.db {
		select from Email where user_id == user_id
	} or { [] }

	return emails
}

pub fn (mut s UserService) find_repo_registered_contributor(id int) []User {
	contributors := sql s.db {
		select from Contributor where repo_id == id
	} or { [] }
	mut users := []User{cap: contributors.len}
	for contributor in contributors {
		user := s.get_user_by_id(contributor.user_id) or { continue }

		users << user
	}
	return users
}

pub fn (mut s UserService) get_all_registered_users_as_page(offset int) []User {
	// FIXME: 30 -> admin_users_per_page
	mut users := sql s.db {
		select from User where is_registered == true limit 30 offset offset
	} or { [] }
	for i, user in users {
		users[i].emails = s.find_user_emails(user.id)
	}
	return users
}

pub fn (mut s UserService) get_all_registered_user_count() int {
	return sql s.db {
		select count from User where is_registered == true
	} or { 0 }
}

pub fn (s UserService) search_users(query string) []User {
	q :=
		'select id, full_name, username, avatar from ${store.sql_table('User')} where is_blocked is false and ' +
		'(username like ${store.sql_like_pattern(query)} or full_name like ${store.sql_like_pattern(query)})'
	repo_rows := store.db_exec_values(s.db, q) or { return [] }
	mut users := []User{}
	for row in repo_rows {
		users << User{
			id:        row[0].int()
			full_name: row[1]
			username:  row[2]
			avatar:    row[3]
		}
	}
	return users
}

pub fn (mut s UserService) get_users_count() !int {
	return sql s.db {
		select count from User
	} or { 0 }
}

pub fn (mut s UserService) get_count_repo_contributors(id int) !int {
	return sql s.db {
		select count from Contributor where repo_id == id
	} or { 0 }
}

pub fn (mut s UserService) contains_contributor(user_id int, repo_id int) bool {
	count := sql s.db {
		select count from Contributor where repo_id == repo_id && user_id == user_id
	} or { 0 }
	return count > 0
}

pub fn (mut s UserService) increment_user_post(mut user User) ! {
	user.posts_count++

	u := *user
	id := u.id
	now := int(time.now().unix())
	lastplus := int(time.unix(u.last_post_time).add_days(1).unix())

	if now >= lastplus {
		user.last_post_time = now
		sql s.db {
			update User set posts_count = 0, last_post_time = now where id == id
		}!
	}

	sql s.db {
		update User set posts_count = posts_count + 1 where id == id
	}!
}

pub fn (mut s UserService) increment_user_login_attempts(user_id int) ! {
	sql s.db {
		update User set login_attempts = login_attempts + 1 where id == user_id
	}!
}

pub fn (mut s UserService) update_user_login_attempts(user_id int, attempts int) ! {
	sql s.db {
		update User set login_attempts = attempts where id == user_id
	}!
}

pub fn (mut s UserService) check_user_blocked(user_id int) bool {
	user := s.get_user_by_id(user_id) or { return false }
	return user.is_blocked
}

fn (mut s UserService) change_username(user_id int, username string) ! {
	sql s.db {
		update User set username = username where id == user_id
	}!

	sql s.db {
		update Repo set user_name = username where user_id == user_id
	}!
}

fn (mut s UserService) change_full_name(user_id int, full_name string) ! {
	sql s.db {
		update User set full_name = full_name where id == user_id
	}!
}

fn (mut s UserService) incement_namechanges(user_id int) ! {
	now := int(time.now().unix())
	sql s.db {
		update User set namechanges_count = namechanges_count + 1, last_namechange_time = now
		where id == user_id
	}!
}

pub fn (mut s UserService) check_username(username string) (bool, User) {
	if username.len == 0 {
		return false, User{}
	}
	mut user := s.get_user_by_username(username) or { return false, User{} }
	return user.is_registered, user
}
