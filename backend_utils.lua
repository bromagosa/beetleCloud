local db = require 'lapis.db' 

function altImageFor (aProject, wantsRaw) 
    local dir = 'projects/' .. math.floor(aProject.id / 1000) .. '/' .. aProject.id -- we store max 1000 projects per dir
    local file = io.open(dir .. '/image.png', 'r')
    if (file) then
        local image = file:read("*all")
        file:close()
        return {
            layout = false, 
            status = 200, 
            readyState = 4,
            image
        }
    else
        return {
            layout = false, 
            status = 200, 
            readyState = 4,
            '/static/img/no-image.png'
        }
    end
end

function getStats() 
    function count (tableName, interval, dateField)
        local query = 'select count(*) from ' .. tableName
        if interval ~= nil then
            query = query .. ' where ' .. dateField .. ' > current_date - interval \'' .. interval .. '\''
        end
        return (db.query(query))[1]['count']
    end
    function sum (tableName, field)
        return (db.query('select sum(' .. field .. ') from ' .. tableName))[1]['sum']
    end

    return {
        projects = {
            total = count('projects'),
            public = count('projects where ispublic'),
            views = sum('projects', 'views'),
            likes = count('likes'),
            haveNotes = count('projects where notes is not null'),
            updatedDuring = {
                thisYear = count('projects', '1 year', 'updated'),
                thisMonth = count('projects', '1 month', 'updated'),
                thisWeek = count('projects', '1 week', 'updated'),
                today = count('projects', '1 day', 'updated')
            },
            sharedDuring = {
                thisYear = count('projects', '1 year', 'shared'),
                thisMonth = count('projects', '1 month', 'shared'),
                thisWeek = count('projects', '1 week', 'shared'),
                today = count('projects', '1 day', 'shared')
            }
        },
        users = {
            total = count('users'),
            admins = count('users where isadmin'),
            haveDescription = count('users where about is not null'),
            haveLocation = count('users where location is not null'),
            joinedDuring = {
                thisYear = count('users', '1 year', 'joined'),
                thisMonth = count('users', '1 month', 'joined'),
                thisWeek = count('users', '1 week', 'joined'),
                today = count('users', '1 day', 'joined')
            }
        }
    }
end
