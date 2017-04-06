_ = require 'underscore'
path = require 'path'
fs = require 'fs'
deepmerge = require 'deepmerge'
colors = require 'colors'
 
walk = (dir, f_match, f_visit) ->
  _walk = (dir) ->
    for filename in fs.readdirSync dir
      filename = dir + '/' + filename
      f_visit(filename) if f_match filename
      _walk(filename) if fs.statSync(filename).isDirectory()
  _walk(dir, dir)
 
console.log("tix-api-test 0.1.0")

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
resolves = {}
isResolvedBy = {}

# Get Calls
loadCall = (filename) ->
  sourceFile = require(filename)
  if sourceFile.Name? and sourceFile.Dependencies?
    callFiles[sourceFile.Name] = path.relative(__dirname,filename)
    if calls[sourceFile.Name]?
      console.log("Error: Duplicate call '#{sourceFile.Name}' (#{callFiles[sourceFile.Name]}) - Previous in '#{callFiles[sourceFile.Name]}'")
      process.exit(2) 

    calls[sourceFile.Name] = sourceFile
    resolves[sourceFile.Name] = {} 
    isResolvedBy[sourceFile.Name] = {}

walk(path.resolve(__dirname,'calls'), matcher, loadCall)

# Filter calls if specified
if process.argv.length == 4
  callPath = process.argv[3]
  console.log("Processing only #{callPath} calls")
  includeCalls = {}
  addDeps = []
  # Get calls that are specified
  addDeps = (name, n = 2) ->
    sourceFile = calls[name]
    for depName in sourceFile.Dependencies
      unless includeCalls[depName]?
        includeCalls[depName] = calls[depName]
        addDeps(depName, n+1)
  for name, filename of callFiles when filename.startsWith("calls/#{callPath}")
    unless includeCalls[name]?
      includeCalls[name] = calls[name]
      addDeps(name)

  filtered = _.difference(_.keys(calls), _.keys(includeCalls))
  for name in filtered
    delete resolves[name]
    delete isResolvedBy[name]
    delete calls[name]
    delete callFiles[name]


# Resolve Dependencies
for name, n of calls
  for depName in n.Dependencies
    unless calls[depName]?
      console.log("Error: Dependency '#{depName}' in call '#{n.Name}' (#{path.relative(__dirname,callFiles[name])}) does not exist.")
      process.exit(2)
    resolves[depName][n.Name] = true
    isResolvedBy[n.Name][depName] = true

# Sort Dependencies (Kahn)
S = []
L = []
for name, sourceFile of calls
 S.push(sourceFile) if sourceFile.Dependencies == null or sourceFile.Dependencies.length == 0   

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
  console.log("Error: Circular dependencies")
  for k1, v of isResolvedBy
    console.log("> "+k1+" (#{path.relative(__dirname,callFiles[k1])}) is unresolved, needs")
    console.log("> - "+k2+" (#{path.relative(__dirname,callFiles[k1])})") for k2, v2 of v
  process.exit(2)  

# Run all tests in order for each environment
totalCount = 0
totalFailed = 0
totalSkipped = 0

testEnvironment = (envfilename) ->
  context = {}

  env = require(envfilename)
  console.log("Testing #{env.Name}")

  context = {}
  count = 0
  failed = 0
  skipped = 0

  nextHandler = (test, ok) ->
    if test?
      count++
      if ok 
        str = "[ #{'PASS'.green}  ]"
      else
        str = "[ #{'FAIL'.red}  ]"
        failed++
      logLeftRight("* #{test.Name}", str)
      test.ResultOK = ok

    loop
      if L.length == 0
        console.log("#{env.Name} - #{count} calls, #{failed} failures, #{skipped} skipped.")
        totalCount += count
        totalFailed += failed
        totalSkipped += skipped

        console.log("Total #{totalCount} calls, #{totalFailed} failures, #{totalSkipped} skipped")
        if totalFailed>0 || totalSkipped>0
          console.log("Failed".red)
          process.exit(1) 

        console.log("Passed".green)
        process.exit(0)

      next = L.shift()
      allDepsOK = true
      for depName in next.Dependencies
        allDepsOK &&= calls[depName].ResultOK
        
      if allDepsOK
        process.nextTick(->
          try 
            next.Do(helpers, env, context, nextHandler) 
          catch e
            logLeftRight("* #{next.Name}", "[ #{'ERROR'.bgRed} ]")
            throw e
        )
        break

      skipped++
      next.ResultOK = false
      logLeftRight("* #{next.Name}", "[ #{'SKIP'.gray}  ]")

  nextHandler(null, false)

# Command line args
if process.argv.length == 2
  testEnvironment(path.resolve(__dirname,'environments/default'))
else if process.argv.length < 5
  testEnvironment(path.resolve(__dirname,'environments/'+process.argv[2]))
else
  console.log("Usage: #{process.argv[0]} [environment_name] [folder]")


