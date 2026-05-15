// Copyright (c) 2019-2021 Alexander Medvednikov. All rights reserved.
// Use of this source code is governed by a GPL license that can be found in the LICENSE file.
module service

import model {Comment}
import store {GitlyDb}
import time


pub struct CommentService {
	db GitlyDb
}


fn (mut s CommentService) add_issue_comment(author_id int, issue_id int, text string) ! {
	comment := Comment{
		author_id:  author_id
		issue_id:   issue_id
		created_at: int(time.now().unix())
		text:       text
	}

	sql s.db {
		insert comment into Comment
	}!
}


