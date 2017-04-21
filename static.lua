-- Static module
-- =============
-- We define pages that don't read from the database and are generally
-- less prone to change here

local app = require 'app'

-- Endpoints

--app:get('/stories', function(self)
--    return { render = 'stories' }
--end)

app:get('/faq', function(self)
    return { render = 'pages/faq' }
end)

app:get('/about', function(self)
    return { render = 'pages/about' }
end)

app:get('/contact', function(self)
    return { render = 'pages/contact' }
end)

app:get('/examples', function(self)
    return { render = 'examples' }
end)

app:get('/run', function(self)
	
    return { render = 'pages/run' }
end)

--app:get('/run', function(self)
--    return { render = 'pages/run' }
--end)


