local app = require 'app'

-- Users and their projects
-- ========================
-- This is where the whole sharing site resides

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
