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
local xml = require('xml')


-- Response generation

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

cors_options = function(self)
    self.res.headers['access-control-allow-headers'] = 'Content-Type'
    self.res.headers['access-control-allow-method'] = 'POST, GET, OPTIONS'
    return { status = 200, layout = false }
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
    self.res.headers['Access-Control-Allow-Origin'] = 'http://localhost:8080'
    self.res.headers['Access-Control-Allow-Credentials'] = 'true'

    if not self.session.username then
        self.session.username = ''
    end
end)


-- Data retrieval

app:get('/api', function(self)
    return { layout = false, 'Beetle Cloud API' }
end)

app:get('/projects/:limit/:offset', function(self)
    return jsonResponse(db.select('projectName, username, thumbnail from projects where isPublic = true order by id desc limit ? offset ?', self.params.limit or 5, self.params.offset or 0))
end)

app:get('/api/users', function(self)
    return jsonResponse(Users:select({ fields = 'username' }))
end)


app:get('/api/users/:username', function(self)
    -- find() doesn't allow for field filtering
    return jsonResponse(Users:select('where username = ?', self.params.username, { fields = 'username' })[1])
end)


app:match('/api/users/:username/projects', respond_to({
    OPTIONS = cors_options,
    GET = function(self)
        -- returns all projects by a user

        if (self.params.username == self.session.username) then
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
    end
}))

app:match('fetchproject', '/api/users/:username/projects/:projectname', respond_to({
    OPTIONS = cors_options,
    GET = function(self)
        local project = Projects:find(self.params.username, self.params.projectname)

        if (project and project.ispublic) then
            return jsonResponse(project)
        elseif (project and self.params.username == self.session.username) then
            return jsonResponse(project)
        else
            return errorResponse('Project ' .. self.params.projectname .. ' is either nonexistent or private')
        end
    end
}))


-- Session management

app:match('login', '/api/users/login', respond_to({
    OPTIONS = cors_options,
    GET = function(self)
        local user = Users:find(self.params.username)

        if (user == nil) then
            return errorResponse('invalid username')
        elseif (bcrypt.verify(self.params.password, user.password)) then
            self.session.username = user.username
            return jsonResponse({ 
                    text = 'User ' .. self.params.username .. ' logged in'
                })
        else
            return errorResponse('invalid password')
        end
    end
}))

app:match('logout', '/api/users/logout', respond_to({
    OPTIONS = cors_options,
    GET = function(self)
        local username = self.session.username
        self.session.username = ''
        return jsonResponse({ 
            text = 'User ' .. username .. ' logged out'
        })
    end
}))


-- Data insertion

app:match('new_user', '/api/users/new', respond_to({
    OPTIONS = cors_options,
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

app:match('save_project', '/api/projects/save', respond_to({
    OPTIONS = cors_options,
    POST = function(self)
        -- can't use camel case because SQL doesn't care about case

        self.params.ispublic = (self.params.ispublic == 'true')

        validate.assert_valid(self.params, {
            { 'projectname', exists = true, min_length = 3 },
            { 'username', exists = true },
            { 'ispublic', type = 'boolean' },
            { 'contents', exists = true }
        })

        if (not Users:find(self.params.username)) then
            return errorResponse('no user with this username exists')
        end

        if (not self.params.username == self.session.username) then
            return errorResponse('are you having fun?')
        end

        ngx.req.read_body()
        local existingProject = Projects:find(self.params.username, self.params.projectname)
        local xmlString = ngx.req.get_body_data()
        local xmlData = xml.load(xmlString)

        if (existingProject) then

            existingProject:update({
                ispublic = self.params.ispublic,
                contents = xmlString,
                updated = db.format_date(),
                notes = xml.find(xmlData, 'notes')[1],
                thumbnail = xml.find(xmlData, 'thumbnail')[1]
            })

            return jsonResponse({ text = 'project ' .. self.params.projectname .. ' updated' })
        end
        
        Projects:create({
            projectname = self.params.projectname,
            username = self.params.username,
            ispublic = self.params.ispublic,
            contents = xmlString,
            updated = db.format_date(),
            notes = xml.find(xmlData, 'notes')[1],
            thumbnail = xml.find(xmlData, 'thumbnail')[1]
        })

        return jsonResponse({ text = 'project ' .. self.params.projectname .. ' created' })
    end
}))
