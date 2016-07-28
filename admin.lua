-- Administration module
-- =====================
-- Admin pages for user managing and so on

local app = require 'app'

app:get('/admin', function(self)
    return 'Administration'
end)

app:get('/migration', function(self)
    if (self.session.username == '') then
        return { render = 'premigration' }
    else
        return { render = 'migration' }
    end
end)

return app
