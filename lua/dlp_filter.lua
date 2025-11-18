-- DLP Filter for Envoy Proxy
-- This script inspects HTTP traffic for sensitive data patterns

-- Simple JSON encoder (cjson is not available in Envoy)
local function escape_json_string(str)
  if str == nil then return "null" end
  str = tostring(str)
  str = string.gsub(str, '\\', '\\\\')
  str = string.gsub(str, '"', '\\"')
  str = string.gsub(str, '\n', '\\n')
  str = string.gsub(str, '\r', '\\r')
  str = string.gsub(str, '\t', '\\t')
  return '"' .. str .. '"'
end

local function encode_json_array(arr)
  local parts = {}
  for _, v in ipairs(arr) do
    table.insert(parts, escape_json_string(v))
  end
  return "[" .. table.concat(parts, ",") .. "]"
end

local function encode_alert(alert)
  local parts = {}
  table.insert(parts, '"pattern":' .. escape_json_string(alert.pattern))
  table.insert(parts, '"severity":' .. escape_json_string(alert.severity))
  table.insert(parts, '"category":' .. escape_json_string(alert.category))
  table.insert(parts, '"count":' .. tonumber(alert.count))
  table.insert(parts, '"source":' .. escape_json_string(alert.source))
  table.insert(parts, '"samples":' .. encode_json_array(alert.samples))
  return "{" .. table.concat(parts, ",") .. "}"
end

local function encode_log_entry(entry)
  local alert_strings = {}
  for _, alert in ipairs(entry.alerts) do
    table.insert(alert_strings, encode_alert(alert))
  end

  local parts = {}
  table.insert(parts, '"timestamp":' .. escape_json_string(entry.timestamp))
  table.insert(parts, '"method":' .. escape_json_string(entry.method))
  table.insert(parts, '"path":' .. escape_json_string(entry.path))
  table.insert(parts, '"authority":' .. escape_json_string(entry.authority))
  table.insert(parts, '"source_ip":' .. escape_json_string(entry.source_ip))
  table.insert(parts, '"alerts":[' .. table.concat(alert_strings, ",") .. "]")

  return "{" .. table.concat(parts, ",") .. "}"
end

-- Load DLP patterns from file (will be loaded once)
local dlp_patterns = {
  {name = "Credit Card", pattern = "%d%d%d%d[%s%-]?%d%d%d%d[%s%-]?%d%d%d%d[%s%-]?%d%d%d%d", severity = "high", category = "PII"},
  {name = "SSN", pattern = "%d%d%d%-%d%d%-%d%d%d%d", severity = "critical", category = "PII"},
  {name = "Email", pattern = "[A-Za-z0-9%._%+%-]+@[A-Za-z0-9%.%-]+%.[A-Za-z][A-Za-z]+", severity = "medium", category = "PII"},
  {name = "API Key Generic", pattern = "[Aa][Pp][Ii]_?[Kk][Ee][Yy]%s*[:%=]%s*['\"]?([A-Za-z0-9_%-]+)['\"]?", severity = "critical", category = "Credentials"},
  {name = "Bearer Token", pattern = "[Bb]earer%s+[A-Za-z0-9%-_]+", severity = "high", category = "Credentials"},
  {name = "Password Field", pattern = "['\"]?[Pp]assword['\"]?%s*[:%=]%s*['\"]([^'\"]+)['\"]", severity = "high", category = "Credentials"},
  {name = "Private Key Header", pattern = "BEGIN%s+RSA%s+PRIVATE%s+KEY", severity = "critical", category = "Credentials"},
  {name = "AWS Access Key", pattern = "AKIA[0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z]", severity = "critical", category = "Credentials"},
  {name = "Phone Number", pattern = "%+?1?[%-.]?%(?[0-9][0-9][0-9]%)?[%-.]?[0-9][0-9][0-9][%-.]?[0-9][0-9][0-9][0-9]", severity = "medium", category = "PII"},
}

-- Function to scan text for sensitive patterns
function scan_for_sensitive_data(text, source)
  local alerts = {}

  if text == nil or text == "" then
    return alerts
  end

  for _, pattern_def in ipairs(dlp_patterns) do
    local matches = {}
    local count = 0

    for match in string.gmatch(text, pattern_def.pattern) do
      count = count + 1
      if count <= 3 then  -- Only store first 3 matches to avoid excessive logging
        -- Mask the matched data for logging
        local masked = string.sub(match, 1, 4) .. "****" .. string.sub(match, -4)
        table.insert(matches, masked)
      end
    end

    if count > 0 then
      table.insert(alerts, {
        pattern = pattern_def.name,
        severity = pattern_def.severity,
        category = pattern_def.category,
        count = count,
        source = source,
        samples = matches
      })
    end
  end

  return alerts
end

-- Function to encode headers as JSON
local function encode_headers(headers_table)
  local parts = {}
  for key, value in pairs(headers_table) do
    if key and value then
      table.insert(parts, escape_json_string(tostring(key)) .. ":" .. escape_json_string(tostring(value)))
    end
  end
  return "{" .. table.concat(parts, ",") .. "}"
end

-- Function to log full request/response to file
function log_full_request(request_info, response_info)
  local timestamp = os.date("%Y-%m-%d %H:%M:%S")
  local log_entry = {
    timestamp = timestamp,
    id = os.time() .. math.random(1000, 9999),
    request = request_info,
    response = response_info or {}
  }

  -- Build JSON manually
  local parts = {}
  table.insert(parts, '"timestamp":' .. escape_json_string(timestamp))
  table.insert(parts, '"id":"' .. log_entry.id .. '"')
  table.insert(parts, '"method":' .. escape_json_string(request_info.method))
  table.insert(parts, '"path":' .. escape_json_string(request_info.path))
  table.insert(parts, '"authority":' .. escape_json_string(request_info.authority))
  table.insert(parts, '"source_ip":' .. escape_json_string(request_info.source_ip))
  table.insert(parts, '"request_headers":' .. encode_headers(request_info.headers))
  table.insert(parts, '"request_body":' .. escape_json_string(request_info.body or ""))

  if response_info then
    table.insert(parts, '"status_code":' .. (response_info.status_code or 0))
    table.insert(parts, '"response_headers":' .. encode_headers(response_info.headers or {}))
    table.insert(parts, '"response_body":' .. escape_json_string(response_info.body or ""))
  end

  table.insert(parts, '"has_alerts":' .. (request_info.has_alerts and "true" or "false"))
  if request_info.alerts and #request_info.alerts > 0 then
    local alert_strings = {}
    for _, alert in ipairs(request_info.alerts) do
      table.insert(alert_strings, encode_alert(alert))
    end
    table.insert(parts, '"alerts":[' .. table.concat(alert_strings, ",") .. "]")
  else
    table.insert(parts, '"alerts":[]')
  end

  local json_entry = "{" .. table.concat(parts, ",") .. "}"

  local log_file = io.open("/var/log/envoy/traffic.log", "a")
  if log_file then
    log_file:write(json_entry .. "\n")
    log_file:close()
  end
end

-- Function to log DLP alerts to file
function log_dlp_alert(handle, alerts, request_info)
  if #alerts == 0 then
    return
  end

  local timestamp = os.date("%Y-%m-%d %H:%M:%S")
  local log_entry = {
    timestamp = timestamp,
    method = request_info.method,
    path = request_info.path,
    authority = request_info.authority,
    source_ip = request_info.source_ip,
    alerts = alerts
  }

  local log_file = io.open("/var/log/envoy/dlp_alerts.log", "a")
  if log_file then
    log_file:write(encode_log_entry(log_entry) .. "\n")
    log_file:close()
  end

  -- Set dynamic metadata for access log
  local metadata_value = string.format("%d_alerts", #alerts)
  handle:streamInfo():dynamicMetadata():set("envoy.lua", "dlp_alert", metadata_value)
end

-- Main request handler
function envoy_on_request(request_handle)
  local headers = request_handle:headers()
  local method = headers:get(":method")
  local path = headers:get(":path")
  local authority = headers:get(":authority")

  -- Capture all headers AND source IP immediately
  local source_ip = tostring(headers:get("x-forwarded-for") or "unknown")
  local headers_table = {}
  for key, value in pairs(headers) do
    if key and value and type(value) == "string" then
      headers_table[tostring(key)] = tostring(value)
    end
  end

  -- Capture request body (must be done immediately, cannot store for later)
  local body_string = ""
  local body_length = 0
  if method == "POST" or method == "PUT" or method == "PATCH" then
    local body = request_handle:body()
    if body then
      body_length = body:length()
      if body_length > 0 and body_length < 10000 then  -- Limit body size for logging
        body_string = tostring(body:getBytes(0, body_length))
      elseif body_length >= 10000 then
        body_string = "(body too large: " .. body_length .. " bytes)"
      end
    end
  end

  local request_info = {
    method = tostring(method or ""),
    path = tostring(path or ""),
    authority = tostring(authority or ""),
    source_ip = source_ip,
    headers = headers_table,
    body = body_string,
    body_length = body_length
  }

  local all_alerts = {}

  -- Scan request headers (use the copied headers_table)
  for key, value in pairs(headers_table) do
    if value and type(value) == "string" then
      local header_alerts = scan_for_sensitive_data(value, "request_header:" .. key)
      for _, alert in ipairs(header_alerts) do
        table.insert(all_alerts, alert)
      end
    end
  end

  -- Scan request body if present
  if body_string and body_string ~= "" then
    local body_alerts = scan_for_sensitive_data(body_string, "request_body")
    for _, alert in ipairs(body_alerts) do
      table.insert(all_alerts, alert)
    end
  end

  -- Add alerts to request_info
  request_info.alerts = all_alerts
  request_info.has_alerts = (#all_alerts > 0)

  -- Log full request details to traffic.log
  log_full_request(request_info, nil)

  -- Log alerts if any found
  if #all_alerts > 0 then
    log_dlp_alert(request_handle, all_alerts, request_info)

    -- Add custom header to indicate DLP detection
    request_handle:headers():add("X-DLP-Alert", "sensitive-data-detected")
  end
end

-- Main response handler
function envoy_on_response(response_handle)
  local headers = response_handle:headers()
  local all_alerts = {}

  local request_info = {
    method = headers:get(":method") or "unknown",
    path = headers:get(":path") or "unknown",
    authority = headers:get(":authority") or "unknown",
    source_ip = "response"
  }

  -- Scan response headers
  for key, value in pairs(headers) do
    if value and type(value) == "string" then
      local header_alerts = scan_for_sensitive_data(value, "response_header:" .. key)
      for _, alert in ipairs(header_alerts) do
        table.insert(all_alerts, alert)
      end
    end
  end

  -- Scan response body
  local body = response_handle:body()
  if body then
    local body_string = body:getBytes(0, body:length())
    local body_alerts = scan_for_sensitive_data(body_string, "response_body")
    for _, alert in ipairs(body_alerts) do
      table.insert(all_alerts, alert)
    end
  end

  -- Log alerts if any found
  if #all_alerts > 0 then
    log_dlp_alert(response_handle, all_alerts, request_info)
  end
end
