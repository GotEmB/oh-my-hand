md5 = require "MD5"
express = require "express"
http = require "http"
socketIo = require "socket.io"
uap = require "./uap"

valueStore = (value, timestamp) ->
	values = []
	values.push value: value, timestamp: (timestamp ? new Date) if value?
	fn = (value, timestamp) ->
		if value?
			ret = values.every (x) -> timestamp > x.timestamp
			values.push value: value, timestamp: (timestamp ? new Date)
			ret
		else
			values.sort((a, b) -> if a.timestamp < b.timestamp then 1 else -1)[0]?.value
	fn.currentTimestamp = ->
		values.sort((a, b) -> if a.timestamp < b.timestamp then 1 else -1)[0]?.timestamp

expressServer = express()
server = http.createServer expressServer
io = socketIo.listen server

expressServer.use express.bodyParser()
expressServer.use express.static __dirname + "/public"

io.sockets.on "connection", (socket) ->

	socket.on "createGame", (callback) ->
		return callback result: false, message: "Game exists" if socket.game?
		socket.game =
			defaults:
				balance: valueStore 1000
				bigBlinds: valueStore 20
				smallBlinds: valueStore 10
		callback
			result: true
			defaults:
				balance: socket.game.defaults.balance()
				bigBlinds: socket.game.defaults.bigBlinds()
				smallBlinds: socket.game.defaults.smallBlinds()

	socket.on "updateDefaults", ({key, value, timestamp}, callback) ->
		return callback result: false, message: "Game does not exist" unless socket.game?
		return callback result: false, message: "Unauthorized access" if socket.player? and !socket.player.admin
		return callback result: false, message: "Invalid key" unless socket.game.defaults.hasOwnProperty key
		if socket.game.defaults[key] value, new Date timestamp ? new Date
			socket.game.players.map((x) -> x.socket).filter((x) -> x isnt socket).forEach (x) -> x.emit "defaultsUpdated"
				key: key
				value: value
				timestamp: timestamp
			callback result: true
		else
			callback
				result: false
				message: "Timestamp obsolete"
				currentValue: socket.game.defaults[key]()
				currentTimestamp: socket.game.defaults[key].currentTimestamp()

	socket.on "addPlayer", ({name}, callback) ->
		return callback result: false, message: "Game does not exist" unless socket.game?
		return callback result: false, message: "Unauthorized access" if socket.player? and !socket.player.admin
		socket.game.players.push thisPlayer =
			token: md5(new Date + "blackjack" + socket.game.players.length + name + io.sockets.clients().length)[1..8]
			name: valueStore name
			balance: valueStore socket.game.defaults.balance()
			admin: valueStore false
		unless socket.player?
			thisPlayer.socket = socket
			socket.player = thisPlayer
			thisPlayer.admin true
			callback result: true, myPlayer: true
		else
			callback result: true
		socket.game.players.map((x) -> x.socket).filter((x) -> x isnt socket).forEach (x) -> x.emit "playerAdded"
			token: thisPlayer.token
			name: thisPlayer.name()
			balance: thisPlayer.balance()
			admin: thisPlayer.admin()
			removable: true #unless played

	socket.on "updatePlayer", ({token, key, value, timestamp}, callback) ->
		return callback result: false, message: "Game does not exist" unless socket.game?
		return callback result: false, message: "Unauthorized access" if socket.player? and !socket.player.admin()
		return callback result: false, message: "Invalid token" unless socket.game.players.some (x) -> x.token is token
		return callback result: false, message: "Invalid key" unless key in ["name", "balance", "admin"]
		return callback result: false, message: "Cannot revoke rights of the only admin" if key is "admin" and value and socket.game.players.filter((x) -> x.admin()).length is 1
		if socket.game.player.filter((x) -> x.token is token)[0][key] value, new Date timestamp ? new Date
			socket.game.players.map((x) -> x.socket).filter((x) -> x isnt socket).forEach (x) -> x.emit "defaultsUpdated"
				token: token
				key: key
				value: value
				timestamp: timestamp
			callback result: true
		else
			callback
				result: false
				message: "Timestamp obsolete"
				currentValue: socket.game.player.filter((x) -> x.token is token)[0][key]()
				currentTimestamp: socket.game.player.filter((x) -> x.token is token)[0][key].currentTimestamp()

	socket.on "removePlayer", ({token}, callback) ->

server.listen process.env.PORT ? 5000