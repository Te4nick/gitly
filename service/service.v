module service

import store

pub struct Service {
pub mut:
	ssh SshService
	token TokenService
	activity ActivityService
	user UserService
	admin AdminService
	commit CommitService
}

pub fn new_service(db store.GitlyDb) !Service {
	token_service := new_token_service(db)
	activity_service := new_activity_service(db)
	user_service:= new_user_service(db, token_service, activity_service, "CHANGEME")
	return Service{
		ssh: new_ssh_service(db)
		token: token_service
		activity: activity_service
		user: user_service
		admin: new_admin_service(user_service)
		commit: new_commit_service(db)
	}
}