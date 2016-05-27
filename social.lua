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


-- Endpoints

app:get('/users', function(self)
    return 'all users'
end)

app:get('/users/:username', function(self)
    self.publicProjects = Projects:find_all(
    { self.params.username }, 
    { 
        key = 'username',
        where = { ispublic = true }
    })
    return { render = 'user' }
end)

app:get('/users/:username/projects', function(self)
    return 'projects by ' .. self.params.username
end)

app:get('/users/:username/projects/:projectname', function(self)
    return 'project ' .. self.params.projectname .. ' by ' .. self.params.username
end)
