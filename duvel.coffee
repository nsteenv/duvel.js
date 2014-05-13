fs = require "fs"
system = require "system"
webpage = require "webpage"

renderPath = "."
authenticityToken = ""

tests = {}

runTests = ->

	tests.index++

	test = tests.json.routes.shift()

	if !test
		tests.endDate = new Date()
		console.log "[" +  Math.round(tests.endDate.getTime() - tests.runDate.getTime()) + "ms] " + tests.file.match(/\/([a-z0-9_]+).json$/)[1]  + " finished"
		phantom.exit 0

	renderUrl test

renderUrl = (test) ->

	page = webpage.create()
	page.viewportSize = if test.viewportSize then test.viewportSize else { width: 1024, height: 768 }
	page.settings.userAgent = "Mozilla/5.0 (Windows NT 6.0; WOW64) AppleWebKit/535.7 (KHTML, like Gecko) Chrome/16.0.912.75 Safari/535.7";

	page.onError = (msg, trace) ->
		console.log "[JS Error] : #{msg}"
		console.log "--------------------"
		for idx, item of trace
			console.log "#{item.function}	#{item.file} : #{item.line}"
		console.log "--------------------"

	if !!tests.json.httpAuth
		page.settings.userName = tests.json.httpAuth.username
		page.settings.password = tests.json.httpAuth.password

	method = "GET"
	if !!test.method
		method = test.method

	data = ""
	if !!test.data
		data += "#{key}=#{value}&" for key, value of test.data

	if !!authenticityToken
		data += "authenticityToken=#{authenticityToken}"

	testUrl = tests.baseUrl + test.route

	if method == "GET" && data
		testUrl += "? #{data}"

	startDate = new Date()

	page.open testUrl, method, data, (status) ->

		openDate = new Date()

		console.log "[" + Math.round(openDate.getTime() - startDate.getTime()) + "ms] #{method} #{testUrl}"

		authenticityToken = page.evaluate ->
			if document.getElementsByName("authenticityToken").length > 0
				return document.getElementsByName("authenticityToken")[0].value

		if !!test.script
#			page.includeJs "http://ajax.googleapis.com/ajax/libs/jquery/1.7.2/jquery.min.js",
			eval("page.evaluate(function(){"+test.script+"});")

		fileName = renderPath + "/" + tests.file.match(/\/([a-z0-9_]+).json$/)[1] + "/"
		fileName += tests.index + test.route.replace(/[\/\*\|\;]/g,"_") + "_#{method}.png"

		setTimeout(
			->
				if status == "success"
					if !test.ignore
						page.render(fileName)
						renderDate = new Date()
						console.log "[" + Math.round(renderDate.getTime() - openDate.getTime()) + "ms] Render #{fileName}"
				else
					console.log "Error opening: #{testUrl}"
					console.log "Status: #{status}"

				endDate = new Date()

				setTimeout runTests, 10

				page.close()

				console.log "[" + Math.round((endDate.getTime() - startDate.getTime())) + "ms] #{fileName} finished"

		, if test.wait then test.wait else 1)

run = ->

	if !!phantom.args[0] && !!phantom.args[1]

		tests.runDate = new Date()
		tests.baseUrl = phantom.args[0]
		tests.file = phantom.args[1]
		tests.index = 0;

		if !!phantom.args[2]
			renderPath = phantom.args[2]

		try
			console.log "Reading tests routes from file: #{tests.file}"
			tests.json = JSON.parse(fs.read(tests.file))
		catch e
			console.log "Could not read file #{tests.file}:\n" + e
			phantom.exit 1

		runTests()

	else
		console.log "Usage: phantomjs capture.coffee <baseUrl> <testFile> [renderPath] [--debug]"
		phantom.exit 1

run()