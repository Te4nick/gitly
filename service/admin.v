module service

pub struct AdminService {
	UserService
}

pub fn new_admin_service(u UserService) AdminService {
	return AdminService{u}
}

pub fn (mut s AdminService) edit_user(user_id int, delete_tokens bool, is_blocked bool, is_admin bool) ! {
	if is_admin {
		s.add_admin(user_id)!
	} else {
		s.remove_admin(user_id)!
	}

	if is_blocked {
		s.block_user(user_id)!
	} else {
		s.unblock_user(user_id)!
	}

	if delete_tokens {
		s.delete_tokens(user_id)!
	}
}

pub fn (mut s AdminService) block_user(user_id int) ! {
	s.set_user_block_status(user_id, true)!
}

pub fn (mut s AdminService) unblock_user(user_id int) ! {
	s.set_user_block_status(user_id, false)!
}

pub fn (mut s AdminService) add_admin(user_id int) ! {
	s.set_user_admin_status(user_id, true)!
}

pub fn (mut s AdminService) remove_admin(user_id int) ! {
	s.set_user_admin_status(user_id, false)!
}
