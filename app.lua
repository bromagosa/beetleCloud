local bcryptlib = require('bcrypt')
local lapis = require('lapis')
local database = require('lapis.db')
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
require 'social'
require 'admin'
