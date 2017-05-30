-- redirect module
-- =============

local app = require 'app'


-- Endpoints

app:get('/workshop', function(self)
    return { redirect_to = "http://www.frauhimbeer.at/blog/" }
end)
