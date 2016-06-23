-- Static module
-- =============
-- We define pages that don't read from the database and are generally
-- less prone to change here

local app = require 'app'

-- Endpoints

app:get('/explore', function(self)
    return { render = 'explore' }
end)


