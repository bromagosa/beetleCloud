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
local respond_to = require('lapis.application').respond_to


-- Utility functions

errorResponse = function(errorText)
    return jsonResponse({ error = errorText })
end

jsonResponse = function(json)
    return {
        layout = false, 
        status = 200, 
        readyState = 4, 
        json = json
    }
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
    -- Set Access Control header
    self.res.headers['Access-Control-Allow-Origin'] = '*'
end)


-- Data retrieval

app:get('/api', function(self)
    return { layout = false, 'Beetle Cloud API' }
end)


app:get('/api/users', function(self)
    return jsonResponse(Users:select({ fields = 'username' }))
end)


app:get('/api/users/:username', function(self)
    -- find() doesn't allow for field filtering
    return jsonResponse(Users:select('where username = ?', self.params.username, { fields = 'username' })[1])
end)


app:get('/api/users/:username/projects', function(self)
    -- returns all public projects by a user

    if (self.params.token == self.session.token) then
        return jsonResponse(Projects:find_all(
            { self.params.username }, 
            { key = 'username' }))
    else
        return jsonResponse(Projects:find_all(
            { self.params.username }, 
            { 
                key = 'username',
                where = { ispublic = true }
            }))
    end
end)

app:match('token', '/api/mytoken', respond_to({
    OPTIONS = function(self)
        self.res.headers['access-control-allow-headers'] = 'Content-Type'
        self.res.headers['access-control-allow-method'] = 'POST'
        return { status = 200, layout = false }
    end,
    GET = function(self)
        print('====SESSION====')
        for k,v in pairs(self.session) do
            print(k .. ' -> ' .. v)
        end
        print('===============')
        return jsonResponse({ token = self.session.token })
    end
}))
    
app:get('/api/users/:username/projects/:projectname', function(self)
    local project = Projects:find(self.params.username, self.params.projectname)

    if (project and project.ispublic) then
        return jsonResponse(project)
    elseif (project and self.params.token == self.session.token) then
        return jsonResponse(project)
    else
        return errorResponse('Project ' .. self.params.projectname .. ' is either nonexistent or private')
    end
end)

-- Session management

app:match('login', '/api/users/login', respond_to({
    OPTIONS = function(self)
        self.res.headers['access-control-allow-headers'] = 'Content-Type'
        self.res.headers['access-control-allow-method'] = 'POST'
        return { status = 200, layout = false }
    end,
    POST = function(self)
        local user = Users:find(self.params.username)

        if (user == nil) then

            return errorResponse('invalid username')

        elseif (bcrypt.verify(self.params.password, user.password)) then

            self.session.token = bcrypt.digest(math.random() .. '', 11)

            return jsonResponse({ 
                    text = 'User ' .. self.params.username .. ' logged in',
                    token = self.session.token
                })
        else

            return errorResponse('invalid password')

        end
    end
}))


-- Data insertion

app:match('new_user', '/api/users/new', respond_to({

    OPTIONS = function(self)

        self.res.headers['access-control-allow-headers'] = 'Content-Type'
        self.res.headers['access-control-allow-method'] = 'POST'

        return { status = 200, layout = false }

    end,

    POST = function(self)

        validate.assert_valid(self.params, {
            { 'username', exists = true, min_length = 3, max_length = 200 },
            { 'password', exists = true, min_length = 3 },
            { 'email', exists = true, min_length = 3 }
        })

        if (Users:find(self.params.username)) then
            return errorResponse('a user with this username already exists')
        end

        Users:create({
            username = self.params.username,
            password = bcrypt.digest(self.params.password, 11),
            email = self.params.email
        })

        return jsonResponse({ text = 'User ' .. self.params.username .. ' created' })

    end
}))

app:post('/api/projects/new', function(self)
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
        return errorResponse('no user with this username exists')
    end

    if (Projects:find(self.params.username, self.params.projectname)) then
        return errorResponse('there is already a project under this name for this user, please choose another name for this project or use /api/projects/update instead')
    end

    Projects:create({
        projectname = self.params.projectname,
        username = self.params.username,
        ispublic = self.params.ispublic,
        thumbnail = self.params.thumbnail,
        contents = self.params.contents
    })

    return jsonResponse({ text = 'project ' .. self.params.projectname .. ' created' })
end)
