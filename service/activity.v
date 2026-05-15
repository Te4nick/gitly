module service

import model { Activity }
import store { GitlyDb }
import time

pub struct ActivityService {
	db GitlyDb
}

pub fn new_activity_service(db GitlyDb) ActivityService {
	return ActivityService{db: db}
}

pub fn (mut s ActivityService) add_activity(user_id int, name string) ! {
	activity := Activity{
		user_id:    user_id
		name:       name
		created_at: time.now()
	}

	sql s.db {
		insert activity into Activity
	}!
}

pub fn (mut s ActivityService) find_activities(user_id int) []Activity {
	return sql s.db {
		select from Activity where user_id == user_id order by created_at desc
	} or { []Activity{} }
}

pub fn (mut s ActivityService) has_activity(user_id int, name string) bool {
	activity_count := sql s.db {
		select count from Activity where user_id == user_id && name == name
	} or { 0 }

	return activity_count > 0
}
