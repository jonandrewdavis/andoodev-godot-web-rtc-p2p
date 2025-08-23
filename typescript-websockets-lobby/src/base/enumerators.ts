export enum EAction {
	Confirm = 'Confirm',
	GetUsers = 'GetUsers',
	PlayerJoin = 'PlayerJoin',
	PlayerLeft = 'PlayerLeft',
	GetLobbies = 'GetLobbies',
	GetOwnLobby = 'GetOwnLobby',
	CreateLobby = 'CreateLobby',
	JoinLobby = 'JoinLobby',
	LeaveLobby = 'LeaveLobby',
	LobbyChanged = 'LobbyChanged',
	GameStarted = 'GameStarted',
	MessageToLobby = 'MessageToLobby',
	PlayerInfoUpdate = 'PlayerInfoUpdate',
	// Web RTC
	NewPeerConnection = 'NewPeerConnection',
	Offer = 'Offer',
	Answer = 'Answer',
	Candidate = 'Candidate',
}

// export enum EGenericAction {
//   UpdatePlayerPosition = "UpdatePlayerPosition",
//   UpdateWeapon = "UpdateWeapon",
// }
