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
	self.page_title = "FAQ"
    return { render = 'pages/faq' }
end)

app:get('/about', function(self)
    self.page_title = "About"
    return { render = 'pages/about' }
end)

app:get('/contact', function(self)
	self.page_title = "Contact"
    return { render = 'pages/contact' }
end)

app:get('/categories', function(self)
	self.page_title = "Categories"
    return { render = 'categories' }
end)

app:get('/run', function(self)
	self.page_title = "Run"
    return { render = 'pages/run' }
end)

--app:get('/run', function(self)
--    return { render = 'pages/run' }
--end)
