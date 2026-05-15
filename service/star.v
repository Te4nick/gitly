module service

import model {Star, Repo}
import store {GitlyDb}

pub struct StarService {
	db GitlyDb
}

fn (mut s StarService) add_star(repo_id int, user_id int) ! {
	star := Star{
		repo_id: repo_id
		user_id: user_id
	}

	sql s.db {
		insert star into Star
	}!
}

fn (mut s StarService) find_user_starred_repos(user_id int) []Repo {
	stars := sql s.db {
		select from Star where user_id == user_id
	} or { [] }
	mut repos := []Repo{}

	for star in stars {
		repo := s.find_repo_by_id(star.repo_id) or { continue }

		repos << repo
	}

	return repos
}

fn (mut s StarService) toggle_repo_star(repo_id int, user_id int) ! {
	is_starred := s.check_repo_starred(repo_id, user_id)

	if is_starred {
		s.remove_star(repo_id, user_id)!
		s.decrement_repo_stars(repo_id)!
	} else {
		s.add_star(repo_id, user_id)!
		s.increment_repo_stars(repo_id)!
	}
}

fn (mut s StarService) check_repo_starred(repo_id int, user_id int) bool {
	stars := sql s.db {
		select from Star where repo_id == repo_id && user_id == user_id limit 1
	} or { [] }

	return stars.len != 0
}

fn (mut s StarService) remove_star(repo_id int, user_id int) ! {
	sql s.db {
		delete from Star where repo_id == repo_id && user_id == user_id
	}!
}
