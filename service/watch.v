module service

import model {Watch}
import store {GitlyDb}

pub struct WatchService {
	db GitlyDb
}

pub fn new_watch_service(db GitlyDb) WatchService {
	return WatchService{db: db}
}

fn (mut s WatchService) watch_repo(repo_id int, user_id int) ! {
	watch := Watch{
		repo_id: repo_id
		user_id: user_id
	}

	sql s.db {
		insert watch into Watch
	}!
}

fn (mut s WatchService) get_count_repo_watchers(repo_id int) int {
	return sql s.db {
		select count from Watch where repo_id == repo_id
	} or { 0 }
}

fn (mut s WatchService) find_watching_repo_ids(user_id int) []int {
	watch_list := sql s.db {
		select from Watch where user_id == user_id
	} or { [] }

	return watch_list.map(it.repo_id)
}

fn (mut s WatchService) toggle_repo_watcher_status(repo_id int, user_id int) ! {
	is_watching := s.check_repo_watcher_status(repo_id, user_id)

	if is_watching {
		s.unwatch_repo(repo_id, user_id)!
	} else {
		s.watch_repo(repo_id, user_id)!
	}
}

fn (mut s WatchService) check_repo_watcher_status(repo_id int, user_id int) bool {
	watches := sql s.db {
		select from Watch where repo_id == repo_id && user_id == user_id limit 1
	} or { [] }

	return watches.len != 0
}

fn (mut s WatchService) unwatch_repo(repo_id int, user_id int) ! {
	sql s.db {
		delete from Watch where repo_id == repo_id && user_id == user_id
	}!
}
