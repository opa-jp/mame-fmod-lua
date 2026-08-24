local user = {}

function user.init()
	print("user script ok.")

	--manager.machine.video.autoframeskip = false
	manager.machine.video.frameskip = 6
end

return user
