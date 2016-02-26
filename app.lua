-- Beetle Cloud
-- ============
-- The Beetle Blocks cloud is both an API for storing user projects and
-- a social site where users can interact with each other

local lapis = require 'lapis'
local app = lapis.Application()

app:enable('etlua')
app.layout = require 'views.layout'

-- Packaging some stuff so it can be accessed from other modules
package.loaded.app = app
package.loaded.db = database
package.loaded.bcrypt = bcryptlib

-- This module only takes care of the index page
app:get('/', function(self)
    return { render = 'index' }
end)

-- Other application aspects are spread over several modules
require 'api'
require 'social'
require 'admin'
