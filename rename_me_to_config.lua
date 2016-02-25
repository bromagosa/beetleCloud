-- You need to rename this file to config.lua and set the proper
-- username, password and database name

local config = require('lapis.config')

config('development', {
  postgres = {
    host = '127.0.0.1:5432',
    user = 'postgres_user',
    password = 'postgres_password',
    database = 'postgres_database'
  },
  port = 9090
})
