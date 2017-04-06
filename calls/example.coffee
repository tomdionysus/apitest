 module.exports =
  Name: 'get_version'
  Dependencies: [ ]

  Do: (t, env, context, next) ->
    t.Call(env, "GET", "blackadder/Test/Tom", null, (http_status, data) ->
      ok = true
      ok &&= http_status < 300
      console.log http_status, data unless ok

      next(module.exports, ok)
    )