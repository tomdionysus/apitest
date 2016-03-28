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
 
console.log("APITest v0.0.1")

matcher = (fn) -> fn.match /\.coffee/

logLeftRight = (left, right) ->
  str = left + (Array(80-left.length-right.length).join(" ")) + right
  console.log(str)

helpers = {}

# Load Helpers
walk(path.resolve(__dirname,'helpers'),matcher,(helperfilename) ->
  helperlib = require(helperfilename)
  helpers[k] = v for k,v in helperlib
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

# Sort Dependencies
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
    console.log("> "+k1+" is unresolved, needs")
    console.log("> - "+k2)for k2, v2 of v
  process.exit(1)  

walk(path.resolve(__dirname,'environments'),matcher,(envfilename) ->

  context = {}

  env = require(envfilename)
  console.log("Testing #{env.Name}")

  fs.writeFile(path.resolve(__dirname,templatename), JSON.stringify(template, null, 2), (err) ->
    console.log("Error: "+err) if err?
  )
)

context = {}
count = 0
failed = 0
for n in L
  count++
  res = n.Do(context, helpers)
  str = if res then "[ PASS ]" else "[ FAIL ]"
  logLeftRight("* #{n.Name}", str)
  failed++ unless res

console.log("Tested #{count} calls, #{failed} failures.")
process.exit(1) if failed>0 

console.log("Done.")


