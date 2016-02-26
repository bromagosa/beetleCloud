-- Administration module
-- =====================
-- Admin pages for user managing and so on

local app = require 'app'

app:get('/admin', function(self)
    return 'Administration'
end)

return app
