import { EAction, EGenericAction } from '../base/enumerators';
import { ClientSocket } from '../models/clientSocket';
import { Lobby } from '../models/lobby';
import { Message } from '../models/message';

import { GameServerHandler } from './game-server-handler';
import { LoggerHelper } from '../helpers/logger-helper';

export class ProtocolHelper {
	public static sendPlayerDisconnectToAll = (gameServer: GameServerHandler, playerDisconnectedId: number) => {
		const playerDisconnectedMessage: Message = new Message(EAction.PlayerLeft, {
			webId: playerDisconnectedId,
		});
		try {
			for (const client of gameServer.connectedClients) {
				try {
					client.socket.send(playerDisconnectedMessage.toString());
				} catch (err: any) {
					LoggerHelper.logError(
						`[ProtocolHelper.sendPlayerDisconnectToAll()] An error had occurred while sending message to client ${client.id}. \n Error: ${err}`
					);
				}
			}
		} catch (err: any) {
			LoggerHelper.logError(
				`[ProtocolHelper.sendPlayerDisconnectToAll()] An error had occurred while notifing a server disconnection: ${err}`
			);
		}
	};

	public static sendPlayerConnectionToAll = (gameServer: GameServerHandler, playerClient: ClientSocket) => {
		const playerConnectedMessage: Message = new Message(EAction.PlayerJoin, {
			username: playerClient.username,
			id: playerClient.id,
			color: playerClient.color,
			lobbyId: playerClient.lobbyId,
			position: playerClient.position,
			direction: playerClient.direction,
		});
		try {
			for (const client of gameServer.connectedClients) {
				try {
					if (client.id != playerClient.id) {
						client.socket.send(playerConnectedMessage.toString());
					}
				} catch (err: any) {
					LoggerHelper.logError(
						`[ProtocolHelper.sendPlayerConnectionToAll()] An error had occurred while sending message to client ${client.id}. \n Error: ${err}`
					);
				}
			}
		} catch (err: any) {
			LoggerHelper.logError(
				`[ProtocolHelper.sendPlayerConnectionToAll()] An error had occurred while notifing a server disconnection: ${err}`
			);
		}
	};

	public static parseReceivingMessage = (
		gameServer: GameServerHandler,
		clientSocket: ClientSocket,
		message: Message,
		secretKey: string
	) => {
		try {
			switch (message.action) {
				case EAction.Connect:
					ProtocolHelper.connectToServer(gameServer, clientSocket, message, secretKey);
					break;
				case EAction.GetUsers:
					ProtocolHelper.sendUserList(gameServer, clientSocket);
					break;
				case EAction.GetLobbies:
					ProtocolHelper.sendLobbyList(gameServer, clientSocket);
					break;
				case EAction.GetOwnLobby:
					ProtocolHelper.sendLobby(gameServer, clientSocket);
					break;
				case EAction.CreateLobby:
					ProtocolHelper.createNewLobby(gameServer, clientSocket);
					break;
				case EAction.LeaveLobby:
					ProtocolHelper.leaveLobby(gameServer, clientSocket, message);
					break;
				case EAction.JoinLobby:
					ProtocolHelper.joinExistingLobby(gameServer, clientSocket, message);
					break;
				case EAction.Heartbeat:
					ProtocolHelper.processHeartbeat(gameServer, clientSocket);
					break;
				case EAction.MessageToLobby:
					ProtocolHelper.sendMessageToLobby(gameServer, clientSocket, message);
					break;
				case EAction.GameStarted:
					LoggerHelper.logInfo('Recieved Lobby Start ' + message);
					ProtocolHelper.startGameForLobby(gameServer, clientSocket, message);
					break;
				case EAction.Offer:
				case EAction.Answer:
				case EAction.Candidate:
					// console.log('DEBUG OFFER', gameServer, clientSocket, message)
					ProtocolHelper.sendOfferAnswerOrCandidate(gameServer, clientSocket, message);
					break;
			}
		} catch (err) {
			LoggerHelper.logError(`[ProtocolHelper.parseReceivingMessage()] An error had occurred while parsing a message: ${err}`);
		}
	};

	private static connectToServer = (gameServer: GameServerHandler, clientSocket: ClientSocket, message: Message, secretKey: string) => {
		try {
			LoggerHelper.logInfo('Connection attempt...');
			if (message.payload.secretKey === secretKey) {
				clearTimeout(clientSocket.logoutTimeout);
				clientSocket.username = message.payload.username;
				clientSocket.color = message.payload.color;
				LoggerHelper.logInfo(`Connection confirmed for ${clientSocket.id}`);

				// Send response
				const connectMessage: Message = new Message(EAction.Connect, {
					webId: clientSocket.id,
				});
				clientSocket.socket.send(connectMessage.toString());

				// Notifies other clients
				for (const client of gameServer.connectedClients) {
					ProtocolHelper.sendUserList(gameServer, client);
				}
			} else {
				LoggerHelper.logWarn(`Connection failed for ${clientSocket.id}`);
				clearTimeout(clientSocket.logoutTimeout);
				clientSocket.socket.close();
				return false;
			}
		} catch (err: any) {
			LoggerHelper.logError(`[ProtocolHelper.connectToServer()] An error had occurred while parsing a message: ${err}`);
		}
	};

	public static sendUserList = (gameServer: GameServerHandler, clientSocket: ClientSocket) => {
		try {
			const userListMessage: Message = new Message(EAction.GetUsers, {
				users: gameServer.connectedClients.map(({ username, id, lobbyId, color }) => {
					return {
						username,
						id,
						lobbyId,
						color,
					};
				}),
			});
			clientSocket.socket.send(userListMessage.toString());
		} catch (err: any) {
			LoggerHelper.logError(`[ProtocolHelper.sendUserList()] An error had occurred while parsing a message: ${err}`);
		}
	};

	public static sendLobbyList = (gameServer: GameServerHandler, clientSocket: ClientSocket) => {
		try {
			const lobbyListMessage: Message = new Message(EAction.GetLobbies, {
				lobbies: gameServer.getLobbies(),
			});
			clientSocket.socket.send(lobbyListMessage.toString());
		} catch (err: any) {
			LoggerHelper.logError(`[ProtocolHelper.sendLobbies()] An error had occurred while parsing a message: ${err}`);
		}
	};

	public static sendLobby = (gameServer: GameServerHandler, clientSocket: ClientSocket) => {
		try {
			const lobby: Lobby | undefined = gameServer.getLobbyByPlayerId(clientSocket.id);
			if (!!lobby) {
				const message = new Message(EAction.GetOwnLobby, {
					lobby: lobby.get(),
				});
				clientSocket.socket.send(message.toString());
			}
		} catch (err: any) {
			LoggerHelper.logError(`[ProtocolHelper.sendLobby()] An error had occurred while parsing a message: ${err}`);
		}
	};

	private static createNewLobby = (gameServer: GameServerHandler, clientSocket: ClientSocket) => {
		try {
			if (gameServer.getLobbyByPlayerId(clientSocket.id)) {
				LoggerHelper.logWarn(`Client ${clientSocket.id} is requesting a new lobby while inside a lobby.`);
				// const invalidLobbyMessage = new Message(EAction.CreateLobby, {
				// 	success: false,
				// });
				// clientSocket.socket.send(invalidLobbyMessage.toString());

				return false;
			} else {
				LoggerHelper.logInfo(`Client ${clientSocket.id} created a new lobby.`);
				const newLobby = gameServer.createLobby();
				newLobby.addPlayer(clientSocket);

				const createLobbySuccessMessage = new Message(EAction.CreateLobby, {});
				clientSocket.socket.send(createLobbySuccessMessage.toString());
				// Alert all clients the changes to the lobbies
				gameServer.connectedClients.forEach((el) => {
					ProtocolHelper.sendLobbyList(gameServer, el);
				});
			}
		} catch (err: any) {
			LoggerHelper.logError(`[ProtocolHelper.createNewLobby()] An error had occurred while parsing a message: ${err}`);
		}
	};

	private static leaveLobby = (gameServer: GameServerHandler, clientSocket: ClientSocket, message: Message) => {
		try {
			const lobby = gameServer.getLobbyByPlayerId(clientSocket.id);
			if (!!lobby) {
				lobby.removePlayer(clientSocket.id);

				const createLobbySuccessMessage = new Message(EAction.LeaveLobby, {});
				clientSocket.socket.send(createLobbySuccessMessage.toString());
				// If the lobby is empty, erase it
				if (lobby.players.length === 0) {
					gameServer.removeLobby(lobby.id);
				} else {
					for (let el of lobby.players) {
						el.socket.send(
							new Message(EAction.PlayerLeft, {
								webId: clientSocket.id,
							}).toString()
						);
					}
				}
				// Alert all clients the changes to the lobbies
				gameServer.connectedClients.forEach((el) => ProtocolHelper.sendLobbyList(gameServer, el));
			}
		} catch (err: any) {
			LoggerHelper.logError(`[ProtocolHelper.leaveLobby()] An error had occurred while parsing a message: ${err}`);
		}
	};

	private static joinExistingLobby = (gameServer: GameServerHandler, clientSocket: ClientSocket, message: Message) => {
		try {
			const lobbyToJoin: Lobby | undefined = gameServer.getLobbyById(message.payload.id);
			if (!!lobbyToJoin) {
				// If the player is already in a lobby, do not allow them to join a new one
				if (clientSocket.lobbyId.length > 1) {
					const joinLobbyFailureMessage = new Message(EAction.JoinLobby, {
						success: false,
					});
					clientSocket.socket.send(joinLobbyFailureMessage.toString());
					return;
				}

				if (lobbyToJoin.addPlayer(clientSocket)) {
					const joinLobbySuccessMessage = new Message(EAction.JoinLobby, {
						lobbyToJoin,
					});
					clientSocket.socket.send(joinLobbySuccessMessage.toString());
					// Alert all clients the changes to the lobbies
					gameServer.connectedClients.forEach((el) => ProtocolHelper.sendLobbyList(gameServer, el));
					lobbyToJoin.players.forEach((el) => {
						ProtocolHelper.sendLobbyChanged(el, lobbyToJoin);
					});

					// TODO: Remove - AD
					// if (lobbyToJoin.players.length >= 2 && !lobbyToJoin.isGameStarted) {
					//   setTimeout(() => {
					//     lobbyToJoin.isGameStarted = true;
					//     lobbyToJoin.players.forEach((el) => {
					//       ProtocolHelper.sendGameStarted(el);
					//     });
					//   }, 1000);
					// }
				}
			} else {
				const joinLobbyFailureMessage = new Message(EAction.JoinLobby, {
					success: false,
				});
				clientSocket.socket.send(joinLobbyFailureMessage.toString());
			}
		} catch (err: any) {
			LoggerHelper.logError(`[ProtocolHelper.joinExistingLobby()] An error had occurred while parsing a message: ${err}`);
		}
	};

	private static startGameForLobby = (gameServer: GameServerHandler, clientSocket: ClientSocket, message: Message) => {
		try {
			const lobbyToStart: Lobby | undefined = gameServer.getLobbyById(message.payload.id);
			if (!!lobbyToStart) {
				// if (lobbyToJoin.addPlayer(clientSocket)) {
				//   const joinLobbySuccessMessage = new Message(EAction.JoinLobby, {
				//     success: true,
				//     lobbyId: lobbyToJoin.id,
				//   });
				//   clientSocket.socket.send(joinLobbySuccessMessage.toString());
				//   // Alert all clients the changes to the lobbies
				//   gameServer.connectedClients.forEach((el) =>
				//     ProtocolHelper.sendLobbyList(gameServer, el)
				//   );
				//   lobbyToJoin.players.forEach((el) => {
				//     ProtocolHelper.sendLobbyChanged(el, lobbyToJoin);
				//   });

				if (lobbyToStart.players.length >= 2 && !lobbyToStart.isGameStarted) {
					setTimeout(() => {
						lobbyToStart.isGameStarted = true;
						lobbyToStart.players.forEach((player) => {
							// Start
							ProtocolHelper.sendGameStarted(player);

							// Share all new sendNewPeerConnection
							var player_client: ClientSocket = player;
							var current_player_id: number = player.id;
							for (const next_player of lobbyToStart.players) {
								if (current_player_id !== next_player.id) {
									ProtocolHelper.sendNewPeerConnection(player_client, next_player.id);
								}
							}
						});
						// TODO: Remove lobby from list, disconnect all players.
						// TODO: Remove lobby from list, disconnect all players.
						// TODO: Remove lobby from list, disconnect all players. Not here, later...
					}, 1000);
				}
			} else {
				// const startGameFailureMessage = new Message(EAction.GameStarted, {
				// 	success: false,
				// });
				// clientSocket.socket.send(startGameFailureMessage.toString());
			}
		} catch (err: any) {
			LoggerHelper.logError(`[ProtocolHelper.startGameForLobby()] An error had occurred while parsing a message: ${err}`);
		}
	};

	// NEW:
	public static sendNewPeerConnection(clientSocket: ClientSocket, next_player_id: number) {
		try {
			const newPeerConnection: Message = new Message(EAction.NewPeerConnection, {
				id: next_player_id,
			});
			clientSocket.socket.send(newPeerConnection.toString());
		} catch (err: any) {
			LoggerHelper.logError(`[ProtocolHelper.sendnewPeerConnection()] An error had occurred while parsing a message: ${err}`);
		}
	}
	// NOTE: NEW!!! WILL IT WORK?
	// TODO: Prettier
	public static sendOfferAnswerOrCandidate(gameServer: GameServerHandler, _clientSocket: ClientSocket, message: Message) {
		try {
			const getClientForMessage: ClientSocket = gameServer.connectedClients.find((client) => client.id === message.payload.peer);
			// NOTE: passes along all of these tob be handled on the client using `message.action`!
			// case EAction.Offer:
			// case EAction.Answer:
			// case EAction.Candidate:

			const newOfferAnswerOrCandidateMessage: Message = new Message(message.action, message.payload);
			getClientForMessage.socket.send(newOfferAnswerOrCandidateMessage.toString());
		} catch (err: any) {
			LoggerHelper.logError(`[ProtocolHelper.sendOfferAnswerOrCandidate()] An error had occurred while parsing a message: ${err}`);
		}
	}

	public static sendGameStarted(clientSocket: ClientSocket) {
		try {
			const sendGameStartedMessage: Message = new Message(EAction.GameStarted, {});
			clientSocket.socket.send(sendGameStartedMessage.toString());
		} catch (err: any) {
			LoggerHelper.logError(`[ProtocolHelper.sendGameStarted()] An error had occurred while parsing a message: ${err}`);
		}
	}

	/**
	 *
	 * @param clientSocket
	 * @param lobbyToJoin
	 */
	public static sendLobbyChanged(clientSocket: ClientSocket, lobbyToJoin: Lobby) {
		try {
			const lobbyListMessage: Message = new Message(EAction.LobbyChanged, {
				lobby: lobbyToJoin.get(),
			});
			clientSocket.socket.send(lobbyListMessage.toString());
		} catch (err: any) {
			LoggerHelper.logError(`[ProtocolHelper.sendLobbyChanged()] An error had occurred while parsing a message: ${err}`);
		}
	}

	/**
	 *
	 * @param gameServer
	 * @param clientSocket
	 */
	private static processHeartbeat = (gameServer: GameServerHandler, clientSocket: ClientSocket) => {
		try {
			const heartBeatMessage: Message = new Message(EAction.Heartbeat, {});
			clientSocket.socket.send(heartBeatMessage.toString());
		} catch (err: any) {
			LoggerHelper.logError(`[ProtocolHelper.processHeartbeat()] An error had occurred while parsing a message: ${err}`);
		}
	};

	/**
	 *
	 * @param gameServer
	 * @param clientSocket
	 * @param message
	 */
	private static sendMessageToLobby = (gameServer: GameServerHandler, clientSocket: ClientSocket, message: Message) => {
		try {
			const lobby: Lobby = gameServer.getLobbyByPlayerId(clientSocket.id);
			if (!!lobby) {
				const lobbyMessage = new Message(EAction.MessageToLobby, { username: clientSocket.username, ...message.payload });
				lobby.players.forEach((el) => {
					// if (el !== clientSocket) {
					el.socket.send(lobbyMessage.toString());
					// }
				});
			}
		} catch (err: any) {
			LoggerHelper.logError(`[ProtocolHelper.sendMessageToLobby()] An error had occurred while parsing a message: ${err}`);
		}
	};
}
