request = require('request')
querystring = require('querystring')

module.exports = 

  CallURL: (verb, url, data, headers, callback) ->
    body =  ""
    if headers['content-type']
      switch headers['content-type']
        when 'application/x-www-form-urlencoded' then body =  querystring.stringify(data)
        else body = JSON.stringify(data)

    options = {
      url: url
      method: verb
      headers: headers
      body: body
    }

    request(options, (error, response, body) ->
      body = ""
      if response.body != ""
        body = JSON.parse(response.body.toString())
      callback(response.statusCode, body, response.headers)
    )

  CallRaw: (env, verb, path, data, headers, callback) ->
    module.exports.CallURL(verb, env.URL+"/"+path, data, headers, callback)

  Call: (env, verb, path, data, callback) ->
    headers =  {
      "content-type": "application/json; charset=UTF-8"
      "accept": "application/json"
    }

    module.exports.CallRaw(env, verb, path, data, headers, callback)

  CallURLForm: (verb, url, form, headers, callback) ->
    headers['content-type'] = 'application/x-www-form-urlencoded'
    module.exports.CallURL(verb, url, form, headers, callback)

  Assert:
    Equal: (expected, actual, message) ->
      return true if expected == actual
      if message?
        console.log message
      else
        console.log("Expected #{expected}, got #{actual}")

