--local host = "www.publicdomain31WWWW8P7.com"
local host = "www.publicdomain317.com"
local certStatus = ngx.shared.certsstatus
local status = certStatus:get(host)

if status and status ~= ngx.null and status ~= "" and status ~= "valid" then
    ngx.log(ngx.OK, "REDIRECT TO HTTP (90)")
    return ngx.redirect("http://" .. ngx.var.host .. ":90" .. ngx.var.request_uri)
end