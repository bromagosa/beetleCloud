-- Social module
-- =============
-- This is where the whole sharing site resides. Within this module there are
-- project pages and user pages

local app = require 'app'
local db = require 'lapis.db' 
local Model = require('lapis.db.model').Model
local config = require "lapis.config".get()
local respond_to = require('lapis.application').respond_to
local md5 = require 'md5'
local bcrypt = require 'bcrypt'


-- Database abstractions

local Users = Model:extend('users', {
    primary_key = { 'username' }
})

local Projects = Model:extend('projects', {
    primary_key = { 'username', 'projectname' }
})

local Likes = Model:extend('likes', {
    primary_key = { 'id' }
})

-- Endpoints

app:get('/signup', function(self)
    self.fail = self.params.fail
    self.reason = self.params.reason
    return { render = 'signup' }
end)

app:get('/user_created', function(self)
    return { render = 'user_created' }
end)

app:get('/tos', function(self)
    return { render = 'tos' }
end)

app:get('/myprojects', function(self)
    self.projects = Projects:select('where username = ? order by id desc', self.session.username, { fields = 'projectname, thumbnail, notes, ispublic, updated' })
    return { render = 'myprojects' }
end)

app:get('/login', function(self)
    self.fail = self.params.fail
    return { render = 'login' }
end)

app:get('/logout', function(self)
    return { redirect_to = '/api/users/logout' }
end)

app:get('/users', function(self)
    return 'all users'
end)

app:get('/users/:username', function(self)
    self.user = Users:find(self.params.username)
    self.user.joinedString = dateString(self.user.joined)
    self.visitor = Users:find(self.session.username)
    return { render = 'user' }
end)

app:get('/users/:username/projects/g/:collection', function(self)
    self.collection = self.params.collection
    self.username = self.params.username
    return { render = 'projectgrid' }
end)

app:get('/projects/g/:collection', function(self)
    self.collection = self.params.collection
    self.username = ''
    return { render = 'projectgrid' }
end)

app:get('/projects/g/tag/:tag', function(self)
	self.collection = "tag"
    self.tag = self.params.tag
    self.username = ''
    self.page_title =  self.params.tag
    return { render = 'projectgrid' }
end)

app:get('/users/:username/projects/:projectname', function(self)
    self.visitor = Users:find(self.session.username)
    self.project = Projects:find(self.params.username, self.params.projectname)

    if (self.project and
        (self.project.ispublic or (self.visitor and self.visitor.isadmin) or
            self.session.username == self.project.username)) then
        self.project.modifiedString = dateString(self.project.updated)
        self.project.sharedString = self.project.ispublic and dateString(self.project.shared) or '-'
        self.project.likes =
            Likes:count('projectname = ? and projectowner = ?', 
                self.params.projectname, 
                self.params.username)
        self.project.likedByUser =
            Likes:count('liker = ? and projectname = ? and projectowner = ?', 
                self.session.username, 
                self.params.projectname, 
                self.params.username) > 0
        
        self.project:update({
            views = (self.project.views or 0) + 1
        })

        return { render = 'project' }
    else
        return { render = 'notfound' }
    end
end)

function dateString(sqlDate)
    if (sqlDate == nil) then return 'never' end
    actualDate = require('date')(sqlDate)
    return string.format('%02d', actualDate:getday()) ..
                '.' .. string.format('%02d', actualDate:getmonth()) ..
                '.' .. actualDate:getyear()
end

app:match('forgot_password', '/forgot_password', respond_to({
    OPTIONS = cors_options,
    POST = function (self)
        local Email = Model:extend('users', {
            primary_key = { 'email'}
        })
        local user = Email:find(self.params.email);

        if (not user) then
            self.page_title = "Recover Password fail"
            self.fail = true
            self.message = "I've flown all over the database but couldn't find this email"
            return { render = 'forgot_password' }
        else
            reset_code = md5.sumhexa(string.reverse(tostring(socket.gettime() * 10000)))
            local options = {reset_code = reset_code}
            user:update(options)
            ok, err = send_mail(self.params.email, "Password reset",
                "Dear BeetleBlocks user, \n\n"
                .. "You requested a reset of your password. Follow this link to create your new password:\n"
                .. self:build_url(self:url_for("password_reset", { reset_code = reset_code }))
                .. config.mail_footer
            )
            if not ok then
                self.fail = true
                self.message = "Sending E-Mail failed: " .. err
            else
                self.success = true
            end

            self.page_title = "Recover Password"
            return { render = 'forgot_password' }
        end
    end,
    GET = function(self)
        self.page_title = "Reset Password"
        return { render = 'forgot_password' }
    end
}))

app:match("password_reset", "/password_reset/:reset_code", respond_to({
    OPTIONS = cors_options,
    POST = function (self)
        self.page_title = "Reset Password"

        local rUser = Model:extend('users', {
            primary_key = { 'reset_code'}
        })
        local user = rUser:find(self.params.reset_code);

        if (not user) then
            self.page_title = "Failed: Reset Password"
            self.fail = true
            self.message = "Your reset code is invalid."
            return { render = 'password_reset' }
        else

            if (self.params.password ~= self.params.confirm_password) then
                self.fail = true
                self.message = "Passwords do not match"
                return { render = 'password_reset' }
            end

            if (string.len(self.params.password) < 3) then
                self.fail = true
                self.message = "Password is too short"
                return { render = 'password_reset' }
            end

            options = {
				password = bcrypt.digest(self.params.password, 11),
                reset_code = ""
            }
            user:update(options)

            self.success = true
            return { render = 'password_reset' }
        end
    end,
    GET = function(self)
        local rUser = Model:extend('users', {
            primary_key = { 'reset_code'}
        })
        local user = rUser:find(self.params.reset_code);
        if (not user) then
            self.page_title = "Failed: Reset Password"
            self.fail = true
            self.message = "Your reset code is invalid."
        else
            self.page_title = "Reset Password"
        end
        return { render = 'password_reset' }
    end
}))

app:match("change_password", "/change_password", respond_to({
    OPTIONS = cors_options,
    POST = function (self)
        self.page_title = "Change Password"
        local user = Users:find(self.session.username)

        if (not user) then
            self.page_title = "Failed: Change Password"
            self.fail = true
            self.message = "You are not logged in"
            return { render = 'change_password' }
        else
			if (bcrypt.verify(self.params.old_password, user.password)) then

				if (self.params.password ~= self.params.confirm_password) then
					self.fail = true
					self.message = "Passwords do not match"
					return { render = 'change_password' }
				end

				if (string.len(self.params.password) < 3) then
					self.fail = true
					self.message = "Password is too short"
					return { render = 'change_password' }
				end

				options = {
					password = bcrypt.digest(self.params.password, 11),
				}
				user:update(options)
			else
				self.fail = true
				self.message = "Old Password is incorrect"
				return { render = 'change_password' }
			end

            self.success = true
            return { render = 'change_password' }
        end
    end,
    GET = function(self)
		local user = Users:find(self.session.username)
		self.page_title = "Change Password"

        if (not user) then
            self.page_title = "Failed: Change Password"
            self.fail = true
            self.message = "You are not logged in"
        end


        return { render = 'change_password' }
    end
}))
