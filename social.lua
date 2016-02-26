-- Social module
-- =============
-- This is where the whole sharing site resides. Within this module there are
-- project pages and user pages

local app = require 'app'

app:get('/users', function(self)
    return 'all users'
end)

app:get('/users/:username', function(self)
    return self.params.username .. '\'s user page'
end)

app:get('/users/:username/projects', function(self)
    return 'projects by ' .. self.params.username
end)

app:get('/users/:username/projects/:projectname', function(self)
    return 'project ' .. self.params.projectname .. ' by ' .. self.params.username
end)
