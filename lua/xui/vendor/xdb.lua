xdb = {}
require 'sqlescape'

local escape = sqlescape.EscapeFunction()
local escapek = function(k)
	assert(string.find(k, "'") == nil)
	return k
end
local escapev = function(v)
	if (type(v) == 'number') then
		v = tostring(v)
	end
	return escape(v)
end

-- escapek("aaaa")
-- escapek("aaaa'")


-- connect to database, dsn should be a valid FS dsn
function xdb.connect(dsn, user, pass)
	xdb.dbh = freeswitch.Dbh(dsn)
	assert(xdb.dbh:connected())
end

-- bind db handle to an existing one
function xdb.bind(dbh)
	xdb.dbh = dbh
end

-- generate insert string from table in kv pairs
local function _insert_string(kvp)
	local comma = ""
	local keys = ""
	local values = ""

	for k, v in pairs(kvp) do
		keys =  keys .. comma .. escapek(k)
		values = values .. comma .. escape(v)
		comma = ","
	end
	return keys, values
end

-- generate update string from table in kv pairs
local function _update_string(kvp)
	local comma = ""
	local str = ""
	for k, v in pairs(kvp) do
		str = str .. comma .. escapek(k) .. "=" .. escape(v)
		comma = ","
	end
	return str
end

-- generate condition string from table in kv pairs
local function _cond_string(kvp)
	if not kvp then return nil end
	if (type(kvp) == "string") then return " WHERE " .. kvp end

	local str = ""
	local and_str = ""

	for k, v in pairs(kvp) do
		str = str .. and_str .. escapek(k) .. "=" .. escapev(v)
		and_str = " AND "
	end

	if str:len() then
		return " WHERE " .. str
	else
		return nil
	end
end

-- create a model, return affected rows, usally 1 on success
function xdb.create(t, kvp)
	local kstr, vstr = _insert_string(kvp)
	sql = "INSERT INTO " .. t .. " (" .. kstr .. ") VALUES (" .. vstr .. ")"
	xdb.dbh:query(sql)
	return xdb.dbh:affected_rows()
end

-- create a model, return the last inserted id, or nil on error
function xdb.create_return_id(t, kvp)
	local ret_id = nil
	if xdb.create(t, kvp) == 1 then
		xdb.dbh:query("SELECT LAST_INSERT_ROWID() as id", function(row)
			ret_id = row.id
		end)
	end

	return ret_id
end

-- create a model, return the last inserted id, or nil on error
function xdb.create_return_object(t, kvp)
	local obj = nil
	if xdb.create(t, kvp) == 1 then
		xdb.dbh:query("SELECT * From " .. t .. " WHERE id = LAST_INSERT_ROWID()", function(row)
			obj = row
		end)
	end

	return obj
end

-- update with kv pairs according a condition table
function xdb.update_by_cond(t, cond, kvp)
	local ustr = _update_string(kvp)
	local cstr = _cond_string(cond)
	local sql = "UPDATE " .. t .. " SET " .. ustr .. cstr
	xdb.dbh:query(sql)
	return xdb.dbh:affected_rows()
end

-- delete and id or with a condition table
function xdb.delete(t, what)
	local cond

	if (type(what) == 'number') then
		cstr = " WHERE id = " .. what
	elseif (type(what) == 'string') then
		cstr = " WHERE id = " .. escape(what)
	else
		cstr = _cond_string(what)
	end

	local sql = "DELETE FROM " .. t

	if cstr then sql = sql .. cstr end

	xdb.dbh:query(sql)
	return xdb.dbh:affected_rows()
end

-- find from table with id = id
function xdb.find(t, id)
	if not type(id) == number then
		id = escape(id)
	end

	local sql = "SELECT * FROM " .. t .. " WHERE id = " .. id
	local found = 0
	local r = nil

	xdb.dbh:query(sql, function(row)
		r = row
	end)

	return r
end

-- find from table
-- if cb is nil, return count of rows and all rows
-- if cb is a callback function, run cb(row) for each row
-- if sort is not nil, ORDER BY sort string

function xdb.find_all(t, sort, cb)
	local sql = "SELECT * FROM " .. t

	if sort then sql = sql .. " ORDER BY " .. sort end

	return xdb.find_by_sql(sql, cb)
end

-- find from table, with WHERE condition cond
-- if cb is nil, return count of rows and all rows
-- if cb is a callback function, run cb(row) for each row
-- if sort is not nil, ORDER BY sort string

function xdb.find_by_cond(t, cond, sort, cb)
	local cstr = _cond_string(cond)
	local sql = "SELECT * FROM " .. t

	if cstr then sql = sql .. cstr end
	if sort then sql = sql .. " ORDER BY " .. sort end

	return xdb.find_by_sql(sql, cb)
end

-- find from table
-- if cb is nil, return count of rows and all rows
-- if cb is a callback function, run cb(row) for each row
function xdb.find_by_sql(sql, cb)
	if (cb) then
		return xdb.dbh:query(sql, cb)
	end

	local rows = {}
	local found = 0

	local cb = function(row)
		found = found + 1
		table.insert(rows, row)
	end

	xdb.dbh:query(sql, cb)

	return found, rows
end

-- update a model
function xdb.update(t, m)
	local id = m.id
	m.id = nil
	return xdb.update_by_cond(t, {id = id}, m)
end

-- execute sql and return affected rows
function xdb.execute(sql)
	xdb.dbh:query(sql)
	return xtra.dbh:affected_rows()
end

-- return the last affacted rows
function xdb.affected_rows()
	return xtra.dbh:affected_rows()
end

xdb.cond = _cond_string;

function xdb.release()
	xdb.dbh:release()
end

return xdb
