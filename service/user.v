module service

import model { User, Email, Contributor, Repo }
import time
import os
import store {UserStore}


const default_avatar_name = 'default_avatar.png' // TODO: extract to common

pub struct UserService {
	TokenService
	ActivityService
	UserStore
	repo_storage_path string
}

pub fn new_user_service(u UserStore, t TokenService, a ActivityService, repo_storage_path string) UserService {
	return UserService{t, a, u, repo_storage_path}
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
			s.set_user_github_status(user.id, true)!
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
