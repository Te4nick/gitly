module model

import time

pub struct Commit {
pub mut:
	id         int @[primary; sql: serial]
	author_id  int
	author     string
	hash       string @[unique: 'commit']
	created_at int
	repo_id    int @[unique: 'commit']
	branch_id  int @[unique: 'commit']
	message    string
}

pub fn (commit Commit) relative() string {
	return time.unix(commit.created_at).relative()
}

pub fn (commit Commit) get_changes(repo Repo) []Change {
	git_changes := repo.git('show ${commit.hash}')

	mut change := Change{}
	mut changes := []Change{}
	mut started := false
	for line in git_changes.split_into_lines() {
		args := line.split(' ')
		if args.len <= 0 {
			continue
		}

		match args[0] {
			'diff' {
				started = true
				if change.file.len > 0 {
					changes << change
					change = Change{}
				}
				change.file = args[2][2..]
			}
			'index' {
				continue
			}
			'---' {
				continue
			}
			'+++' {
				continue
			}
			'@@' {
				change.diff = line
			}
			else {
				if started {
					if line.bytes()[0] == `+` {
						change.additions++
					}
					if line.bytes()[0] == `-` {
						change.deletions++
					}
					change.message += '${line}\n'
				}
			}
		}
	}

	changes << change

	return changes
}

pub struct Change {
pub mut:
	file      string
	additions int
	deletions int
	diff      string
	message   string
}