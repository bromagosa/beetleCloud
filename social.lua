-- Social module
-- =============
-- This is where the whole sharing site resides. Within this module there are
-- project pages and user pages

local app = require 'app'
local db = require 'lapis.db' 
local Model = require('lapis.db.model').Model

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

app:get('/forum', function(self)
    return { render = 'notready' }
end)

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
    return { render = 'user' }
end)

app:get('/users/:username/projects/g/:list', function(self)
    return 'projects by ' .. self.params.username
end)

app:get('/users/:username/projects/:projectname', function(self)
    self.project = Projects:find(self.params.username, self.params.projectname)
    if (self.project and
        (self.project.ispublic or
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
