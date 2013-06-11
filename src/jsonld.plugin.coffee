module.exports = (BasePlugin) ->

	class JsonldPlugin extends BasePlugin

		name: 'jsonld'

		config:
			map:
				date:		'http://purl.org/dc/elements/1.1/date'
				title:		'http://purl.org/dc/elements/1.1/title'
				tags:		'http://purl.org/dc/elements/1.1/subject'

		buildJson: (document, map) ->
			ldobject =
				'@id': document.get('url')
				'@context': {}
			for property, uri of map
				ldobject[property] = document.get(property)
				ldobject['@context'][property] = uri
			return ldobject

		writeAfter: (opts, next) ->
			config = @config
			database = docpad.getCollection('html')
			{TaskGroup} = require('taskgroup')
			safefs = require('safefs')
			pathUtil = require('path')
			buildJson = @buildJson

			getJsonContent = (document) ->
				JSON.stringify buildJson(document, config.map), null, 4

			tasks = new TaskGroup().setConfig(concurrency:0).once 'complete', (err) ->
				docpad.log 'debug', 'Wrote static clean url files'
				return next(err)

			addWriteTask = (outPath, outContent, encoding) ->
				tasks.addTask (complete) ->
					return safefs.writeFile(outPath, outContent, encoding, complete)

			database.forEach (document) ->
				return  if document.get('write') is false or document.get('ignore') is true or document.get('render') is false

				primaryUrl = document.get('url')
				primaryOutPath = document.get('outPath')
				ext = pathUtil.extname(primaryOutPath)
				jsonOutPath = pathUtil.join(pathUtil.dirname(primaryOutPath), pathUtil.basename(primaryOutPath, ext)) + '.jsonld'
				addWriteTask jsonOutPath, getJsonContent(document), document.get('encoding')

			tasks.run()
			return next();
