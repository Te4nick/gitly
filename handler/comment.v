module handler

import veb

@['/:username/:repo_name/comments'; post]
pub fn (mut app App) handle_add_comment(username string, repo_name string) veb.Result {
	app.find_repo_by_name_and_username(repo_name, username) or { return ctx.not_found() }
	text := ctx.form['text']
	issue_id := ctx.form['issue_id']
	is_text_empty := validation.is_string_empty(text)
	is_issue_id_empty := validation.is_string_empty(issue_id)
	if is_text_empty || is_issue_id_empty || !ctx.logged_in {
		ctx.error('Issue comment is not valid')
		return app.issue(mut ctx, username, repo_name, issue_id)
	}
	app.add_issue_comment(ctx.user.id, issue_id.int(), text) or {
		ctx.error('There was an error while inserting the comment')
		return app.issue(mut ctx, username, repo_name, issue_id)
	}
	// TODO: count comments
	app.increment_issue_comments(issue_id.int()) or { app.info(err.str()) }
	return ctx.redirect('/${username}/${repo_name}/issue/${issue_id}')
}