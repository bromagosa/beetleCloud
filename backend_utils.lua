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
            '/static/no-image.png'
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


function dateString(sqlDate)
    if (sqlDate == nil) then return 'never' end
    actualDate = require('date')(sqlDate)
    return string.format('%02d', actualDate:getday()) ..
                '.' .. string.format('%02d', actualDate:getmonth()) ..
                '.' .. actualDate:getyear()
end


send_mail =  function (rcpt, subject, body)
    local socket = require 'socket'
    local base = _G
    -----------------------------------------------------------------------------
    -- Mega hack. Don't try to do this at home.
    -----------------------------------------------------------------------------
    -- we can't yield across calls to protect on Lua 5.1, so we rewrite it with
    -- coroutines
    -- make sure you don't require any module that uses socket.protect before
    -- loading our hack

    if string.sub(base._VERSION, -3) == "5.1" then
      local function _protect(co, status, ...)
        if not status then
          local msg = ...
          if base.type(msg) == 'table' then
            return nil, msg[1]
          else
            base.error(msg, 0)
          end
        end
        if coroutine.status(co) == "suspended" then
          return _protect(co, coroutine.resume(co, coroutine.yield(...)))
        else
          return ...
        end
      end

      function socket.protect(f)
        return function(...)
          local co = coroutine.create(f)
          return _protect(co, coroutine.resume(co, ...))
        end
      end
    end

    local smtp = require 'socket.smtp'
    local ssl = require 'ssl'
    local https = require 'ssl.https'
    local ltn12 = require 'ltn12'
    local config = require "lapis.config".get()

    function sslCreate()
        local sock = socket.tcp()
        return setmetatable({
            connect = function(_, host, port)
                local r, e = sock:connect(host, port)
                if not r then return r, e end
                sock = ssl.wrap(sock, {mode='client', protocol='tlsv1'})
                return sock:dohandshake()
            end
        }, {
            __index = function(t,n)
                return function(_, ...)
                    return sock[n](sock, ...)
                end
            end
        })
    end


    local msg = {
        headers = {
            from = config.mail_from_name .. " <" .. config.mail_from .. ">",
            to = rcpt,
            subject = subject
        },
        body = body
    }

    local ok, err = smtp.send {
        from = config.mail_from,
        rcpt = rcpt,
        source = smtp.message(msg),
        user = config.mail_user,
        password = config.mail_password,
        server = config.mail_server,
        port = 465,
        create = sslCreate
    }

    return ok, err
end
