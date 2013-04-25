require.config
	paths:
		knockout: "//ajax.aspnetcdn.com/ajax/knockout/knockout-2.2.1"
		bootstrap: "lib/bootstrap"
		jquery: "//code.jquery.com/jquery-1.9.1.min"
		underscore: "//cdnjs.cloudflare.com/ajax/libs/underscore.js/1.4.4/underscore-min"
	shim:
		underscore: exports: "_"
		bootstrap: deps: ["jquery"]

require [
	"knockout"
	"jquery"
	#"bootstrap"
], (ko, $) ->

	window.app = app =
		container: ko.observable "startScreen"
		balance:
			value: ko.observable "1000"
		bigBlind:
			value: ko.observable "20"
		smallBlind:
			value: ko.observable "10"
		players: ko.observableArray []
		selectedPlayer: ko.observable null
		currentPlayer: ko.observable null
		addPlayerInput: ko.observable ""
		playerDND:
			mousedown: (context, e) ->
				return true if app.playerDND.state?
				return true if e.changedTouches? and e.changedTouches.length isnt 1
				e.preventDefault?()
				app.playerDND.state =
					context: context
					startY: e.clientY or e.y or e.changedTouches[0].clientY
					domNode: e.currentTarget.parentElement
					shift: 0
				e.currentTarget.parentElement.style.zIndex = 10
			mousemove: (context, e) ->
				return true unless app.playerDND.state?
				return true if e.changedTouches? and e.changedTouches.length isnt 1
				e.preventDefault?()
				movedDistance = (e.clientY or e.y or e.changedTouches[0].clientY) - app.playerDND.state.startY
				currentPosition = do ->
					pos = 0
					i = 0
					while app.playerDND.state.domNode.parentElement.children[i] isnt app.playerDND.state.domNode
						pos += app.playerDND.state.domNode.parentElement.children[i].clientHeight
						i++
					pos + i - 1
				bounds =
					min: app.playerDND.state.domNode.parentElement.children[0].clientHeight - currentPosition
					max: app.playerDND.state.domNode.parentElement.clientHeight - app.playerDND.state.domNode.clientHeight - currentPosition - 3
				movedDistance = bounds.min if movedDistance < bounds.min
				movedDistance = bounds.max if movedDistance > bounds.max
				app.playerDND.state.domNode.style.top = movedDistance + "px"
				app.playerDND.state.shift = movedDistance
				node.style.top = "0px" for node in app.playerDND.state.domNode.parentElement.children when node isnt app.playerDND.state.domNode
				if Math.abs(movedDistance) > app.playerDND.state.domNode.clientHeight
					idx = $(app.playerDND.state.domNode).index()
					for i in [(movedDistance / Math.abs movedDistance) .. (movedDistance / app.playerDND.state.domNode.clientHeight)]
						app.playerDND.state.domNode.parentElement.children[idx + i].style.top = (-(movedDistance / Math.abs movedDistance) * (app.playerDND.state.domNode.clientHeight + 1)) + "px"
			mouseup: (context, e) ->
				return true unless app.playerDND.state?
				return true if e.changedTouches? and e.changedTouches.length isnt 1
				e.preventDefault?()
				app.playerDND.state.domNode.style.zIndex = 0
				node.style.top = "0px" for node in app.playerDND.state.domNode.parentElement.children
				idx = app.players.indexOf app.playerDND.state.context
				shx = parseInt app.playerDND.state.shift / app.playerDND.state.domNode.clientHeight
				app.players.splice idx + shx, 0, (app.players.splice idx, 1)...
				delete app.playerDND.state
		setupNewGame: ->
			window.history.pushState container: "setupNewGame", "Oh My Hand!", ""
			app.container "setupNewGame"
		addPlayer: (context, event) ->
			return true unless (event.which or event.keyCode) is 13 and app.addPlayerInput() isnt ""
			app.players.push thisPlayer =
				token: "Blackjack"
				name: ko.observable app.addPlayerInput()
				balance: ko.observable app.balance.value()
				admin: ko.observable app.players().length is 0
				selectPlayer: ->
					app.selectedPlayer thisPlayer
				toggleAdmin: ->
					thisPlayer.admin !thisPlayer.admin()
				removePlayer: ->
					app.players.remove thisPlayer
			app.currentPlayer thisPlayer unless app.currentPlayer()?
			app.addPlayerInput ""
	window.onpopstate = (event) ->
		console.log event.state
		return app.container "startScreen" unless event.state?
		app.container event.state.container
	
	$ ->
		#$('body').tooltip selector: "[rel=tooltip]"
		ko.applyBindings app