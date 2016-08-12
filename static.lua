-- Static module
-- =============
-- We define pages that don't read from the database and are generally
-- less prone to change here

local app = require 'app'

-- Endpoints

app:get('/stories', function(self)
    return { render = 'stories' }
end)

app:get('/examples', function(self)
    return { render = 'examples' }
end)

