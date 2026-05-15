module service

import model {Release}
import store {GitlyDb}
import time

pub struct ReleaseService {
	db GitlyDb
}

pub fn (mut s ReleaseService) add_release(tag_id int, repo_id int, date time.Time, notes string) ! {
	release := Release{
		tag_id:  tag_id
		repo_id: repo_id
		notes:   notes
		date:    date
	}

	sql s.db {
		insert release into Release
	}!
}

pub fn (mut s ReleaseService) find_repo_releases_as_page(repo_id int, offset int) []Release {
	// FIXME: 20 -> releases_per_page
	return sql s.db {
		select from Release where repo_id == repo_id order by date desc limit 20 offset offset
	} or { []Release{} }
}

pub fn (s ReleaseService) get_repo_release_count(repo_id int) int {
	return sql s.db {
		select count from Release where repo_id == repo_id
	} or { 0 }
}

pub fn (mut s ReleaseService) delete_repo_releases(repo_id int) ! {
	sql s.db {
		delete from Release where repo_id == repo_id
	}!
}
