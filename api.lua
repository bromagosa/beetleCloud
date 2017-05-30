-- API module
-- ==========
-- User creation, project uploading, project fetching and so on

local app = require 'app'
local app_helpers = require 'lapis.application'
local validate = require 'lapis.validate'
local md5 = require 'md5'
local bcrypt = require 'bcrypt'
local db = require 'lapis.db'
local Model = require('lapis.db.model').Model
local util = require('lapis.util')
local respond_to = require('lapis.application').respond_to
local xml = require('xml')
local config = require "lapis.config".get()
local unistd = require "posix.unistd"
salt = "21"

require 'backend_utils'

-- Response generation

errorResponse = function (errorText)
    return jsonResponse({ error = errorText })
end

jsonResponse = function (json)
    return {
        layout = false,
        status = 200,
        readyState = 4,
        json = json
    }
end

cors_options = function (self)
    self.res.headers['access-control-allow-headers'] = 'Content-Type'
    self.res.headers['access-control-allow-method'] = 'POST, GET, OPTIONS'
    return { status = 200, layout = false }
end

err = {
    notLoggedIn = errorResponse('you are not logged in'),
    auth = errorResponse('authentication error'),
    notfound = errorResponse('not found'),
    nonexistentUser = errorResponse('no user with this username exists'),
    nonexistentProject = errorResponse('this project does not exist, or you do not have permissions to access it')
}

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

local Comments = Model:extend('comments', {
    primary_key = { 'id' }
})



-- Before filter

app:before_filter(function (self)
    -- unescape all parameters
    for k,v in pairs(self.params) do
        self.params[k] = util.unescape(v)
    end

    -- Set Access Control header
    self.res.headers['Access-Control-Allow-Origin'] = 'http://localhost:8080'
    self.res.headers['Access-Control-Allow-Credentials'] = 'true'

    if (not self.session.username) then
        self.session.username = ''
    end
end)


-- Data retrieval

app:get('/api', function (self)
    return { layout = false, 'Beetle Cloud API' }
end)

app:get('/api/users', function (self)
    return jsonResponse(Users:select({ fields = 'username' }))
end)

app:get('/api/users/:username', function (self)
    -- find() doesn't allow for field filtering
    return jsonResponse(Users:select('where username = ?', self.params.username, { fields = 'username, location, about, joined' })[1])
end)

app:get('/api/users/:username/gravatar', function (self)
    local user = Users:find(self.params.username)

    if (user) then
        return {
            layout = false,
            status = 200,
            readyState = 4,
            "http://www.gravatar.com/avatar/"
                .. md5.sumhexa(user.email)
                .. "?s=64&d=http%3A%2F%2Fbeta.turtlestitch.org%2Fstatic%2Fimg%2Fturtle.png"
        }
    else
        return err.nonexistentUser
    end
end)

app:get('/api/users/:username/become', function (self)
    local visitor = Users:find(self.session.username)

    if (visitor and visitor.isadmin) then
        self.session.username = self.params.username
        return jsonResponse({ text = visitor.username .. ' became ' .. self.params.username })
    else
        return err.auth
    end
end)

app:get('/api/projects/:selection/:limit/:offset(/:username)', function (self)

    local username = self.params.username or 'Examples'
    local list = self.params.list or ''
    local tag = self.params.tag or ''
    local notes = self.params.notes or ''

    local query = {
        newest = 'projectName, username from projects where isPublic = true order by id desc',
        popular = 'count(*) as likecount, projects.projectName, projects.username from projects, likes where projects.isPublic = true and projects.projectName = likes.projectName and projects.username = likes.projectowner group by projects.projectname, projects.username order by likecount desc',
        favorite = 'distinct projects.id, projects.projectName, projects.username from projects, likes where projects.projectName = likes.projectName and projects.username = likes.projectowner and likes.liker = \'' .. username .. '\' group by projects.projectname, projects.username order by projects.id desc',
        shared = 'projectName, username from projects where isPublic = true and username = \'' .. username .. '\' order by id desc',
        notes = 'projectName, username from projects where isPublic = true and username = \'' .. username .. '\' and notes ilike \'%' .. notes .. '%\' order by id desc',
        tag = 'projectName, username from projects where isPublic = true and admin_tags ilike \'%' .. tag .. '%\' order by id desc',
        list = 'projectName, username from projects where isPublic = true and username = \'' .. username .. '\' and projectName in ' .. list ..  ' order by id desc'
    }

    return jsonResponse(
        db.select(
            query[self.params.selection] .. ' limit ? offset ?',
            self.params.limit or 5,
            self.params.offset or 0))
end)

app:get('/api/users/:username/projects/:projectname/image', function (self)
    local project = Projects:find(self.params.username, self.params.projectname)

    if (project) then
        if (project.imageisfeatured) then
            return altImageFor(project)
        else
            return {
                layout = false,
                status = 200,
                readyState = 4,
                project.thumbnail
            }
        end
    else
        return err.nonexistentProject
    end
end)

app:match('project_list', '/api/users/:username/projects', respond_to({
    OPTIONS = cors_options,
    GET = function (self)
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
    GET = function (self)
        local project = Projects:find(self.params.username, self.params.projectname)
        local visitor = Users:find(self.session.username)

        if (project and (project.ispublic or (visitor and visitor.isadmin) or self.params.username == self.session.username)) then
            return jsonResponse(project)
        else
            return err.nonexistentProject
        end
    end
}))

app:get('/api/search/:query', function (self)
    local query = '.*' .. self.params.query .. '.*'
    local matchingUsers = Users:select('where username ~* ? or about ~* ? order by id desc limit 10', query, query, { fields = 'username' })
    local matchingProjects = Projects:select('where ispublic = \'true\' and projectname ~* ? or notes ~* ? order by id desc limit 10', query, query, { fields = 'projectname, username' })
    return jsonResponse({ users = matchingUsers, projects = matchingProjects })
end)

-- Session management

app:match('login', '/api/users/login', respond_to({
    OPTIONS = cors_options,
    GET = function (self)
        local user = Users:find(self.params.username)
        local comesFromWebClient = ngx.var.http_referer:match('/run') == nil

        if (user == nil) then
            if comesFromWebClient then
                return { redirect_to = '/login?fail=true' }
            else
                return errorResponse('invalid username')
            end
        --elseif (bcrypt.verify(self.params.password, user.password)) then
        elseif (unistd.crypt(self.params.password, salt) == user.password) then
            self.session.username = user.username
            self.session.email = user.email
            self.session.gravatar = md5.sumhexa(user.email)
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
    GET = function (self)
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

app:match('current_user', '/api/user', respond_to({
    -- Gives back the currently logged user
    OPTIONS = cors_options,
    GET = function (self)
        return jsonResponse({ username = self.session.username })
    end
}))


-- Data insertion

app:match('new_user', '/api/users/new', respond_to({
    OPTIONS = cors_options,
    POST = function (self)
        local comesFromWebClient = ngx.var.http_referer:match('/run') == nil

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
            --password = bcrypt.digest(self.params.password, 11),
            password = unistd.crypt(self.params.password, salt),
            email = self.params.email,
            isadmin = false,
            joined = db.format_date()
        })

        if (comesFromWebClient) then
            return { redirect_to = '/user_created' }
        else
            return jsonResponse({ text = 'User ' .. self.params.username .. ' created' })
        end
    end
}))

app:match('update_user', '/api/users/:username/update/:property', respond_to({
    OPTIONS = cors_options,
    POST = function (self)
        local user = Users:find(self.params.username);

        if (not user) then
            return err.nonexistentUser
        end

        if (self.params.username ~= self.session.username) then
            return err.auth
        end

        local options = {}
        ngx.req.read_body()
        options[self.params.property] = ngx.req.get_body_data()
        user:update(options)

    end
}))

app:match('update_project', '/api/users/:username/projects/:projectname/update/:property', respond_to({
    OPTIONS = cors_options,
    POST = function (self)
        local project = Projects:find(self.params.username, self.params.projectname);


        if (not project) then
            return err.nonexistentProject
        end

        if (self.params.property == 'admin_tags') then
            local visitor = Users:find(self.session.username)
            if (not visitor.isadmin) then
                return err.auth
            end
        else
            if (self.params.username ~= self.session.username) then
                return err.auth
            end
        end

        local options = {}
        ngx.req.read_body()
        options[self.params.property] = ngx.req.get_body_data()
        if (self.params.property == 'notes') then
            -- Special case! Notes are saved both in a column and inside the XML
            local xmlData = xml.load(project.contents)
            xml.find(xmlData, 'notes')[1] = options['notes']
            options['contents'] = xml.dump(xmlData)
        end

        if options['admin_tags'] == nil then
            options['admin_tags'] = ""
        end
        project:update(options)

    end
}))

app:match('save_project', '/api/projects/save', respond_to({
    OPTIONS = cors_options,
    POST = function (self)
        -- can't use camel case because SQL doesn't care about case

        self.params.ispublic = (self.params.ispublic == 'true')

        validate.assert_valid(self.params, {
            { 'projectname', exists = true, min_length = 3 },
            { 'username', exists = true },
            { 'ispublic', type = 'boolean' },
            { 'contents', exists = true }
        })

        if (not Users:find(self.params.username)) then
            return err.nonexistentUser
        end

        if (self.params.username ~= self.session.username) then
            return err.auth
        end

        ngx.req.read_body()
        local existingProject = Projects:find(self.params.username, self.params.projectname)
        local xmlString = ngx.req.get_body_data()
        local xmlData = xml.load(xmlString)

        if (existingProject) then

            existingProject:update({
                contents = xmlString,
                updated = db.format_date(),
                notes = xml.find(xmlData, 'notes')[1] or '',
                thumbnail = xml.find(xmlData, 'thumbnail')[1]
            })

            if ((existingProject.shared == nil and self.params.ispublic == 'true')
                or (self.params.ispublic == 'true' and not existingProject.ispublic)) then
                existingProject:update({ shared = db.format_date() })
            end

            return jsonResponse({ text = 'project ' .. self.params.projectname .. ' updated' })

        else

            project = Projects:create({
                projectname = self.params.projectname,
                username = self.params.username,
                ispublic = self.params.ispublic,
                contents = xmlString,
                updated = db.format_date(),
                notes = xml.find(xmlData, 'notes')[1] or '',
                thumbnail = xml.find(xmlData, 'thumbnail')[1]
            })

            if (self.params.ispublic == 'true') then
                project:update({ shared = db.format_date() })
            end

            return jsonResponse({ text = 'project ' .. self.params.projectname .. ' created' })

        end
    end
}))

app:match('set_visibility', '/api/users/:username/projects/:projectname/visibility', respond_to({
    OPTIONS = cors_options,
    GET = function (self)
        local visitor = Users:find(self.session.username)

        if (not Users:find(self.params.username)) then
            return err.nonexistentUser
        end

        if (self.params.username ~= self.session.username and not (visitor or visitor.isadmin)) then
            return err.auth
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
            return err.nonexistentProject
        end

    end
}))

app:match('remove_project', '/api/users/:username/projects/:projectname/delete', respond_to({
    OPTIONS = cors_options,
    GET = function (self)
        -- can't use camel case because SQL doesn't care about case
        local visitor = Users:find(self.session.username)

        if (not Users:find(self.params.username)) then
            return err.nonexistentUser
        end

        if (self.params.username ~= self.session.username and not (visitor or visitor.isadmin)) then
            return err.auth
        end

        local project = Projects:find(self.params.username, self.params.projectname)

        if (project) then
            db.delete('likes', { projectowner = self.params.username, projectname = self.params.projectname })
            project:delete()
            return jsonResponse({ text = 'project ' .. self.params.projectname .. ' removed' })
        else
            return err.nonexistentProject
        end

    end
}))

app:match('toggle_like', '/api/users/:username/projects/:projectname/like', respond_to({
    OPTIONS = cors_options,
    GET = function (self)
        -- can't use camel case because SQL doesn't care about case

        if (not self.session.username) then
            return err.notLoggedIn
        end

        if (self.session.username == self.params.username) then
            return jsonResponse({ text = 'of course you do, it\'s your own project! ;)'})
        end

        local project = Projects:find(self.params.username, self.params.projectname)
        local user = Users:find(self.params.username)

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

                if (user.notify_like) then
                    ok, err = send_mail(user.email, "Someone likes your project",
                        "Dear " .. self.params.username .. ", \n\n"
                        .. "Your project \"" .. self.params.projectname .. "\" got "
                        .. "a thumb up from user "
                        .. self.session.username .. "\n\n"
                        .. "Visit your project and see all likes here: \n"
                        .. self:build_url("/users/" .. self.params.username .. "/projects/" .. util.escape(self.params.projectname))
                        .. config.mail_footer
                    )
                end

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
            return err.nonexistentProject
        end
    end
}))

app:match('alternate_image', '/api/users/:username/projects/:projectname/altimage', respond_to({
    OPTIONS = cors_options,
    GET = function (self)

        local project = Projects:find(self.params.username, self.params.projectname)

        if (not project) then
            return err.nonexistentProject
        end

        if (self.params.featureImage) then
            -- we got the featureImage parameter, meaning we want to change the featured image
            -- for this project

            if (not self.session.username) then
                return err.notLoggedIn
            end

            if (self.params.username ~= self.session.username) then
                return err.auth
            end

            project:update({ imageisfeatured = self.params.featureImage == 'true' })
        else
            -- we are just asking for the alternate image for this project
            return altImageFor(project)
        end
    end,
    POST = function (self)
        if (not self.session.username) then
            return err.notLoggedIn
        end

        if (self.params.username ~= self.session.username) then
            return err.auth
        end

        local project = Projects:find(self.params.username, self.params.projectname)

        if (project) then
            ngx.req.read_body();
            image = ngx.req.get_body_data();
            local dir = 'projects/' .. math.floor(project.id / 1000) .. '/' .. project.id -- we store max 1000 projects per dir
            os.execute('mkdir -p ' .. dir)
            local file = io.open(dir .. '/image.png', 'w+')
            file:write(image)
            file:close()
            return jsonResponse('image uploaded')
        else
            return err.nonexistentProject
        end
    end
}))

-- Stats

app:match('stats', '/api/stats', respond_to({
    OPTIONS = cors_options,
    GET = function (self)
        return jsonResponse(getStats())
    end
}))

-- comments

app:match('new_comment', '/api/comments/new', respond_to({
    OPTIONS = cors_options,
    POST = function (self)

        validate.assert_valid(self.params, {
            { 'projectname', exists = true, min_length = 3 },
            { 'projectowner', exists = true },
            { 'author', exists = true, min_length = 3 },
            { 'contents', exists = true, min_length = 3 }
        })

        if (string.len(self.params.contents) < 3) then
             return errorResponse('comment too short')
        end

        if (self.params.author ~= self.session.username) then
            return err.auth
        end

        local existingProject = Projects:find(self.params.projectowner, self.params.projectname)

        if (existingProject) then
            self.params.contents = self.params.contents:gsub("^%s*(.-)%s*$", "%1")
            self.params.contents = self.params.contents:gsub("%b<>", "")
            comment = Comments:create({
                projectname = self.params.projectname,
                author = self.params.author,
                contents = self.params.contents,
                projectowner = self.params.projectowner,
                date = os.date()
            })

            if (self.params.author ~= self.params.projectowner) then
                user = Users:find(self.params.projectowner)
                if (user.notify_comment) then
                    ok, err = send_mail(user.email, "New comment",
                        "Dear " .. self.params.projectowner .. ", \n\n"
                        .. "Your project \"" .. self.params.projectname .. "\" received "
                        .. "a new comment from user "
                        .. self.params.author .. "\n\n"
                        .. "Visit your project and read all comments here: \n"
                        .. self:build_url("/users/" .. self.params.projectowner .. "/projects/" .. util.escape(self.params.projectname))
                        .. config.mail_footer
                    )
                end
            end
            return jsonResponse({ comment = comment})
        else
            return err.nonexistentProject
        end
    end
}))


app:get('/api/users/:username/projects/:projectname/comments', function (self)
    return jsonResponse(
    --    Comments:select('where projectowner = ? and projectname = ? order by id desc',
    --    self.params.username,
    --    self.params.projectname)
        db.select(
            'distinct comments.contents, comments.id, comments.date, username as author, md5(email) as gravatar from comments, users where comments.projectname = ? and comments.projectowner = ? and comments.author = users.username order by comments.id desc',
            self.params.projectname,
            self.params.username)
    )
end)

app:get('/api/comment/:id', function (self)
    return jsonResponse(
    db.select(
        'distinct comments.contents, comments.date, users.username as author, md5(users.email) as gravatar from comments, users where comments.id = ? and comments.author = users.username',
        self.params.id)
    )
end)


app:get('/api/comment/delete/:id', function (self)
    local visitor = Users:find(self.session.username)
    local comment = Comments:find(self.params.id)

    if (not comment) then
        return err.notfound
    end

    if (self.params.username ~= self.session.username and not (visitor or visitor.isadmin)) then
        return err.auth
    end

    comment:delete()

    return jsonResponse({ text = 'comment removed', id = self.params.id })

end)
