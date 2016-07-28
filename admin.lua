-- Administration module
-- =====================
-- Admin pages for user managing and so on

local app = require 'app'

app:get('/admin', function(self)
    return 'Administration'
end)

app:get('/migration', function(self)
    return { render = 'migration' }
end)

return app
