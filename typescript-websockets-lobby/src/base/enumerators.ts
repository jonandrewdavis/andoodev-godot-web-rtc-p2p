export enum EAction {
  Connect = "Connect",

  GetUsers = "GetUsers",
  PlayerJoin = "PlayerJoin",
  PlayerLeft = "PlayerLeft",

  GetLobbies = "GetLobbies",
  GetOwnLobby = "GetOwnLobby",
  CreateLobby = "CreateLobby",
  JoinLobby = "JoinLobby",
  LobbyChanged = "LobbyChanged",
  LeaveLobby = "LeaveLobby",

  GameStarted = "GameStarted",

  MessageToLobby = "MessageToLobby",
  Heartbeat = "Heartbeat",

  // NOTE: Added
  NewPeerConnection = "NewPeerConnection",

  Offer = "Offer",
  Answer = "Answer",
  Candidate = "Candidate",

}

export enum EGenericAction {
  UpdatePlayerPosition = "UpdatePlayerPosition",
  UpdateWeapon = "UpdateWeapon",
}
