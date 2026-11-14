local args = {
	1
}
game:GetService("ReplicatedStorage"):WaitForChild("LoadGameEvent"):FireServer(unpack(args))
