_ = require 'underscore'
path = require 'path'
fs = require 'fs'
deepmerge = require 'deepmerge'
 
walk = (dir, f_match, f_visit) ->
  _walk = (dir) ->
    for filename in fs.readdirSync dir
      filename = dir + '/' + filename
      f_visit(filename) if f_match filename
      _walk(filename) if fs.statSync(filename).isDirectory()
  _walk(dir, dir)
 
console.log("apitest 0.1.0")

matcher = (fn) -> fn.match /\.coffee/

logLeftRight = (left, right) ->
  str = left + (Array(80-left.length-right.length).join(" ")) + right
  console.log(str)

helpers = {}

# Load Helpers
walk(path.resolve(__dirname,'helpers'),matcher,(helperfilename) ->
  helperlib = require(helperfilename)
  helpers[k] = v for k,v of helperlib
)

# Load Calls
calls = {}
callFiles = {}
S = []
L = []

resolves = {}
isResolvedBy = {}

walk(path.resolve(__dirname,'calls'), matcher, (filename) ->
  sourceFile = require(filename)
  if sourceFile.Name? and sourceFile.Dependencies?
    callFiles[sourceFile.Name] = filename
    if calls[sourceFile.Name]?
      console.log("Error: Duplicate call '#{sourceFile.Name}' (#{path.relative(__dirname,filename)}) - Previous in '#{path.relative(__dirname,callFiles[sourceFile.Name])}'")
      process.exit(2) 
    
    calls[sourceFile.Name] = sourceFile
    resolves[sourceFile.Name] = {} 
    isResolvedBy[sourceFile.Name] = {}
    S.push(sourceFile) if sourceFile.Dependencies == null or sourceFile.Dependencies.length == 0      
)

# Resolve Dependencies
for name, n of calls
  for depName in n.Dependencies
    unless calls[depName]?
      console.log("Error: Dependency '#{depName}' in call '#{n.Name}' (#{path.relative(__dirname,callFiles[name])}) does not exist.")
      process.exit(2)
    resolves[depName][n.Name] = true
    isResolvedBy[n.Name][depName] = true

# Sort Dependencies (Kahn)
while true
  break if S.length == 0 
  n = S.pop()
  L.push(n)
  for depName, x of resolves[n.Name]
    delete isResolvedBy[depName][n.Name]
    if Object.keys(isResolvedBy[depName]).length == 0
      delete isResolvedBy[n.Name]
      S.push(calls[depName])
  delete isResolvedBy[n.Name]

if Object.keys(isResolvedBy).length > 0
  console.log("Error: Circular dependenies")
  for k1, v of isResolvedBy
    console.log("> "+k1+" (#{path.relative(__dirname,callFiles[k1])}) is unresolved, needs")
    console.log("> - "+k2+" (#{path.relative(__dirname,callFiles[k1])})") for k2, v2 of v
  process.exit(2)  

# Run all tests in order for each environment
totalCount = 0
totalFailed = 0

walk(path.resolve(__dirname,'environments'),matcher,(envfilename) ->
  context = {}

  env = require(envfilename)
  console.log("Testing #{env.Name}")

  context = {}
  count = 0
  failed = 0

  nextHandler = (test, ok) ->
    if test?
      count++
      if ok 
        str = "[ PASS  ]"
      else
        str = "[ FAIL  ]"
        failed++
      logLeftRight("* #{test.Name}", str)

    if L.length == 0
      console.log("#{env.Name} - #{count} calls, #{failed} failures.")
      totalCount += count
      totalFailed += failed

      console.log("Tested Total #{totalCount} calls, #{totalFailed} failures.")
      process.exit(1) if totalFailed>0 

      console.log("Done.")
      process.exit(0)

    next = L.shift()
    process.nextTick(->
      try 
        next.Do(helpers, env, context, nextHandler) 
      catch e
        logLeftRight("* #{next.Name}", "[ ERROR ]")
        throw e
    )

  nextHandler(null, false)
)
