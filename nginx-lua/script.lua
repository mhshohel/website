local ngx                   = require "ngx"
local cjson                 = require "cjson"
--local http                  = require("socket.http")
--local http                  = require("http")

local options = {
    method = ngx.req.get_method(),
    req_headers = ngx.req.get_headers(),
    resp_headers = ngx.resp.get_headers(),
    body = ngx.req.read_body(),
    post_params = ngx.req.get_post_args(),
    uri = ngx.req.get_uri_args(),
    host = ngx.var.host,
    server_port = ngx.var.server_port,
    scheme = ngx.var.scheme,
    http_status = ngx.status
}

--ngx.say(cjson.encode(options))

local res = ngx.location.capture("/api/result.php",
    { method = ngx.HTTP_GET,
        body = "ping\\r\\n" }
)
ngx.print("[" .. res.body .. "]")



--http.get("https://nodemcu.readthedocs.io/en/master/en/modules/http/", nil, function(code, data)
--    if (code ~= 200) then
--        print("HTTP request failed")
--    else
--        print(code, data)
--    end
--end)


--https.request {
--    method = args[1],
--    url = args[2],
--    source = ltn12.source.string(reqbody),
--    headers = {
--        ["Content-Type"] = "application/x-www-form-urlencoded",
--        ["Content-Length"] = #reqbody
--    },
--    sink = ltn12.sink.table(respbody)
--}






