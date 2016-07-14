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

local Comments = Model:extend('comments', {
    primary_key = { 'id' }
})

local Likes = Model:extend('likes', {
    primary_key = { 'id' }
})


-- Before filter

app:before_filter(function(self)
    -- unescape all parameters
    for k,v in pairs(self.params) do
        self.params[k] = util.unescape(v)
    end

    -- Set Access Control header
--    self.res.headers['Access-Control-Allow-Origin'] = 'http://localhost:8080'
    self.res.headers['Access-Control-Allow-Credentials'] = 'true'

    if (not self.session.username) then
        self.session.username = ''
    end
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

app:get('/api/projects/:selection/:limit/:offset(/:username)', function(self)

    local username = self.params.username or 'Examples'
    local list = self.params.list or ''
    local notes = self.params.notes or ''

    local query = { 
        newest = 'projectName, username, thumbnail from projects where isPublic = true order by id desc',
        popular = 'count(*) as likecount, projects.projectName, projects.username, projects.thumbnail from projects, likes where projects.isPublic = true and projects.projectName = likes.projectName and projects.username = likes.projectowner group by projects.projectname, projects.username order by likecount desc',
        favorite = 'distinct projects.id, projects.projectName, projects.username, projects.thumbnail from projects, likes where projects.projectName = likes.projectName and projects.username = likes.projectowner and likes.liker = \'' .. username .. '\' group by projects.projectname, projects.username order by projects.id desc',
        shared = 'projectName, username, thumbnail from projects where isPublic = true and username = \'' .. username .. '\' order by id desc',
        notes = 'projectName, username, thumbnail from projects where isPublic = true and username = \'' .. username .. '\' and notes = \'' .. notes .. '\' order by id desc',
        list = 'projectName, username, thumbnail from projects where isPublic = true and username = \'' .. username .. '\' and projectName in ' .. list ..  ' order by id desc'
    }

    return jsonResponse(
        db.select(
            query[self.params.selection] ..' limit ? offset ?',
            self.params.limit or 5,
            self.params.offset or 0))
end)

app:match('project_list', '/api/users/:username/projects', respond_to({
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

app:match('fetch_project', '/api/users/:username/projects/:projectname', respond_to({
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

app:match('fetch_comments', '/api/users/:username/projects/:projectname/comments', respond_to({
    OPTIONS = cors_options,
    GET = function(self)

        local project = Projects:find(self.params.username, self.params.projectname)

        if (project and project.ispublic) then
            return jsonResponse(Comments:select('where projectowner = ? and projectname = ?', self.params.username, self.params.projectname, { fields = 'contents, author, date' }))
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
        local comesFromWebClient = string.sub(ngx.var.http_referer,-5) == 'login'

        if (user == nil) then
            if comesFromWebClient then
                return { redirect_to = '/login?fail=true' }
            else
                return errorResponse('invalid username')
            end
        elseif (bcrypt.verify(self.params.password, user.password)) then
            self.session.username = user.username
            if comesFromWebClient then
                return { redirect_to = '/' }
            else
                return jsonResponse({ 
                    text = 'User ' .. self.params.username .. ' logged in'
                })
            end
        else
            if comesFromWebClient then
                return { redirect_to = '/login?fail=true' }
            else
                return errorResponse('invalid password')
            end
        end
    end
}))

app:match('logout', '/api/users/logout', respond_to({
    OPTIONS = cors_options,
    GET = function(self)
        local username = self.session.username
        local comesFromWebClient = ngx.var.http_referer:match('/run') == nil
        self.session.username = ''
        if comesFromWebClient then
            return { redirect_to = '/' }
        else
            return jsonResponse({ 
                text = 'User ' .. username .. ' logged out'
            })
        end
    end
}))


-- Data insertion

app:match('new_user', '/api/users/new', respond_to({
    OPTIONS = cors_options,
    POST = function(self)
        local comesFromWebClient = string.sub(ngx.var.http_referer,-6) == 'signup'

        validate.assert_valid(self.params, {
            { 'username', exists = true, min_length = 3, max_length = 200 },
            { 'password', exists = true, min_length = 3 },
            { 'email', exists = true, min_length = 3 }
        })

        if (comesFromWebClient and not self.params.password == self.params.password_repeat) then
                return { redirect_to = '/signup?fail=true&reason=Passwords%20do%20not%20match' }
        end

        if (Users:find(self.params.username)) then
            if (comesFromWebClient) then
                return { redirect_to = '/signup?fail=true&reason=Username%20already%20exists' }
            else
                return errorResponse('a user with this username already exists')
            end
        end

        Users:create({
            username = self.params.username,
            password = bcrypt.digest(self.params.password, 11),
            email = self.params.email,
            joined = db.format_date()
        })
            if (comesFromWebClient) then
                return { redirect_to = '/user_created' }
            else
                return jsonResponse({ text = 'User ' .. self.params.username .. ' created' })
            end
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

        if (self.params.username ~= self.session.username) then
            return errorResponse('authentication error')
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

            if (existingProject.ispublic ~= (self.params.ispublic == 'true')) then
                existingProject:update({ shared = db.format_date() })
            end

            return jsonResponse({ text = 'project ' .. self.params.projectname .. ' updated' })
        end
        
        project = Projects:create({
            projectname = self.params.projectname,
            username = self.params.username,
            ispublic = self.params.ispublic,
            contents = xmlString,
            updated = db.format_date(),
            notes = xml.find(xmlData, 'notes')[1],
            thumbnail = xml.find(xmlData, 'thumbnail')[1]
        })

        if (self.params.ispublic == 'true') then
            project:update({ shared = db.format_date() })
        end

        return jsonResponse({ text = 'project ' .. self.params.projectname .. ' created' })
    end
}))

app:match('set_visibility', '/api/users/:username/projects/:projectname/visibility', respond_to({
    OPTIONS = cors_options,
    GET = function(self)

        if (not Users:find(self.params.username)) then
            return errorResponse('no user with this username exists')
        end

        if (self.params.username ~= self.session.username) then
            return errorResponse('authentication error')
        end

        local project = Projects:find(self.params.username, self.params.projectname)

        if (project) then
            project:update({ ispublic = self.params.ispublic == 'true' })
            if (self.params.ispublic == 'true') then
                project:update({ shared = db.format_date() })
            end

            return jsonResponse({ 
                text = 'project ' .. self.params.projectname .. ' is now ' ..
                (self.params.ispublic == 'true' and 'public' or 'private')
            })
        else
            return errorResponse('project does not exist')
        end
        
    end
}))

app:match('remove_project', '/api/users/:username/projects/:projectname/delete', respond_to({
    OPTIONS = cors_options,
    GET = function(self)
        -- can't use camel case because SQL doesn't care about case

        if (not Users:find(self.params.username)) then
            return errorResponse('no user with this username exists')
        end

        if (self.params.username ~= self.session.username) then
            return errorResponse('authentication error')
        end

        local project = Projects:find(self.params.username, self.params.projectname)

        if (project) then
            project:delete()
            return jsonResponse({ text = 'project ' .. self.params.projectname .. ' removed' })
        else
            return errorResponse('project does not exist')
        end
        
    end
}))

app:match('new_comment', '/api/comments/new', respond_to({
    OPTIONS = cors_options,
    POST = function(self)
        -- can't use camel case because SQL doesn't care about case

        validate.assert_valid(self.params, {
            { 'projectowner', exists = true },
            { 'username', exists = true },
            { 'author', exists = true }
        })

        if (not Users:find(self.params.projectowner) or not Users:find(self.params.author)) then
            return errorResponse('no user with this username exists')
        end

        if (self.params.author ~= self.session.username) then
            return errorResponse('authentication error')
        end

        ngx.req.read_body()
        local project = Projects:find(self.params.projectowner, self.params.projectname)

        if (project) then

            Comments:create({
                projectname = self.params.projectname,
                projectowner = self.params.projectowner,
                author = self.params.author,
                contents = req.get_body_data(),
                date = db.format_date()
            })

            return jsonResponse({ text = 'comment added' })
        else
            return errorResponse('could not find project')
        end
    end
}))

app:match('toggle_like', '/api/users/:username/projects/:projectname/like', respond_to({
    OPTIONS = cors_options,
    GET = function(self)
        -- can't use camel case because SQL doesn't care about case

        if (not self.session.username) then
            return errorResponse('you are not logged in')
        end

        local project = Projects:find(self.params.username, self.params.projectname)

        if (project) then

            if (Likes:count('liker = ? and projectname = ? and projectowner = ?', 
                self.session.username, 
                self.params.projectname, 
                self.params.username) == 0) then

                Likes:create({
                    projectname = self.params.projectname,
                    projectowner = self.params.username,
                    liker = self.session.username
                })

                return jsonResponse({ text = 'project liked' })
            else
                db.delete(
                    'likes',
                    'liker = ? and projectname = ? and projectowner = ?',
                    self.session.username, 
                    self.params.projectname, 
                    self.params.username)
                return jsonResponse({ text = 'project unliked' })
            end

        else
            return errorResponse('could not find project')
        end
    end
}))
