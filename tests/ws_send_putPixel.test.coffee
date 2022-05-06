target = require '../src/web/index/script/ws.coffee'

test "calctest", ->
	expect target.ws_send_chat 'wow'
		.toBe 'notthis'