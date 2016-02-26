-- API module
-- ==========
-- User creation, project uploading, project fetching and so on

local app = require 'app'
local app_helpers = require 'lapis.application'
local validate = require 'lapis.validate'
local bcrypt = require 'bcrypt'
local db = require 'lapis.db' 
local Model = require('lapis.db.model').Model

local capture_errors_json = app_helpers.capture_errors_json
local yield_error = app_helpers.yield_error

-- Database abstractions

local Users = Model:extend('users', {
    primary_key = { 'username' }
})

local Projects = Model:extend('projects', {
    primary_key = { 'username', 'projectName' }
})

-- API endpoints

app:get('/api', function(self)
    return { layout = false, 'Beetle Cloud API' }
end)

app:get('/api/users', function(self)
    return { layout = false, json = Users:select({ fields = 'username' }) }
end)

app:get('/api/users/:username', function(self)
    -- find() doesn't allow for field filtering
    return { layout = false, json = Users:select('where username = ?', self.params.username, { fields = 'username' })[1] }
end)

app:get('/api/users/:username/projects', function(self)
    return { layout = false, json = Projects:find_all({ self.params.username }, 'username') }
end)

app:get('/api/users/:username/projects/:projectName', function(self)
    return { layout = false, json = Projects:find(self.params.username, self.params.projectName) }
end)

app:post('/api/users/new', capture_errors_json(function(self)
    
    validate.assert_valid(self.params, {
        { 'username', exists = true, min_length = 3, max_length = 200 },
        { 'password', exists = true, min_length = 3 },
        { 'email', exists = true, min_length = 3 }
    })

    if (Users:find(self.params.username) ~= nil) then
        yield_error('a user with this username already exists')
    end

    -- passwords should travel over SSL, this needs to be studied and set up 
    -- in config.lua

    Users:create({
        username = self.params.username,
        password = bcrypt.digest(self.params.password, 11),
        email = self.params.email
    })

    return { layout = false, json = { ok = 'user ' .. self.params.username .. ' created' }}
end))

app:post('/api/projects/new', capture_errors_json(function(self)
    
    validate.assert_valid(self.params, {
        { 'projectName', exists = true, min_length = 3 },
        { 'username', exists = true },
        { 'isPublic', exists = true, type = 'boolean' },
        { 'thumbnail', exists = true },
        { 'contents', exists = true }
    })

    if (Users:find(self.params.username) == nil) then
        yield_error('no user with this username exists')
    end

    -- passwords should travel over SSL, this needs to be studied and set up 
    -- in config.lua

    Users:create({
        username = self.params.username,
        password = bcrypt.digest(self.params.password, 11),
        email = self.params.email
    })

    return { layout = false, json = { ok = 'user ' .. self.params.username .. ' created' }}
end))
