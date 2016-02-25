local app = require 'app'
local db = require 'db'
local bcrypt = require 'bcrypt'

-- Administration
-- ==============
-- Admin pages for user managing and so on

app:get('/table/:tablename', function(self)
    self.rows = db.query('select * from ' .. self.params.tablename)

    return { render = 'table' }
end)

return app
