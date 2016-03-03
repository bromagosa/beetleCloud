-- API module
-- ==========
-- User creation, project uploading, project fetching and so on

local app = require 'app'
local app_helpers = require 'lapis.application'
local validate = require 'lapis.validate'
local bcrypt = require 'bcrypt'
local db = require 'lapis.db' 
local Model = require('lapis.db.model').Model
local util = require('lapis.util')

local capture_errors_json = app_helpers.capture_errors_json
local yield_error = app_helpers.yield_error


-- Utility functions

function unescapeTable(table)
end


-- Database abstractions

local Users = Model:extend('users', {
    primary_key = { 'username' }
})

local Projects = Model:extend('projects', {
    primary_key = { 'username', 'projectname' }
})


-- Before filter

app:before_filter(function(self)
    -- unescape all parameters
    for k,v in pairs(self.params) do
        self.params[k] = util.unescape(v)
    end
end)


-- Data retrieval

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
    -- returns all public projects by a user
    return { layout = false, json = Projects:find_all({ self.params.username }, { 
        key = 'username',
        where = { ispublic = true }
    } )}
end)


app:get('/api/users/:username/projects/:projectname', function(self)
    local project = Projects:find(self.params.username, self.params.projectname)

    if (project and project.ispublic) then
        return { layout = false, json = project }
    else
        return { layout = false, json = { error = 'Project ' .. self.params.projectname .. ' is either nonexistent or private' } }
    end
end)


-- Data insertion

app:post('/api/users/new', capture_errors_json(function(self)
    validate.assert_valid(self.params, {
        { 'username', exists = true, min_length = 3, max_length = 200 },
        { 'password', exists = true, min_length = 3 },
        { 'email', exists = true, min_length = 3 }
    })

    if (not Users:find(self.params.username)) then
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
    -- This should actually be /api/users/:username/projects/new, but for
    -- some reason it seems you can only use URL parameters if you go the
    -- respond_to() way, not when using the post() wrapper
    --
    -- see: http://leafo.net/lapis/reference/actions.html#handling-http-verbs

    -- can't use camel case because SQL doesn't care about case

    self.params.ispublic = (self.params.ispublic == 'true')

    validate.assert_valid(self.params, {
        { 'projectname', exists = true, min_length = 3 },
        { 'username', exists = true },
        { 'ispublic', type = 'boolean' },
        { 'thumbnail', exists = true },
        { 'contents', exists = true }
    })

    if (not Users:find(self.params.username)) then
        yield_error('no user with this username exists')
    end

    if (Projects:find(self.params.username, self.params.projectname)) then
        yield_error('there is already a project under this name for this user, please choose another name for this project or use /api/projects/update instead')
    end

    Projects:create({
        projectname = self.params.projectname,
        username = self.params.username,
        ispublic = self.params.ispublic,
        thumbnail = self.params.thumbnail,
        contents = self.params.contents
    })

    return { layout = false, json = { ok = 'project ' .. self.params.projectname .. ' created' }}
end))
