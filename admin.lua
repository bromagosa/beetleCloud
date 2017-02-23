-- Administration module
-- =====================
-- Admin pages for user managing and so on

local app = require 'app'
local Model = require('lapis.db.model').Model

-- Database abstractions

local Users = Model:extend('users', {
    primary_key = { 'username' }
})

app:get('/admin', function(self)
    local visitor = Users:find(self.session.username)
    if visitor.isadmin then
        return { render = 'admin' }
    else
        return { render = 'noaccess' }
    end
end)

app:get('/stats', function(self)
    require 'backend_utils'
    self.stats = getStats()
    return { render = 'stats' }
end)

app:get('/migration', function(self)
    if (self.session.username == '') then
        return { render = 'premigration' }
    else
        return { render = 'migration' }
    end
end)

return app
