import { EAction } from "../base/enumerators";
import { LoggerHelper } from "../helpers/logger-helper";

export class Message {
  action: EAction;
  payload: any;

  constructor(action: EAction, payload: any) {
    try {
      this.action = action;
      this.payload = payload;
    } catch (err) {
      LoggerHelper.logError(
        `An error had occurred while creating a message: ${err}`
      );
    }
  }

  static fromString(message: String): Message {
    try {
      const parsedMessage = JSON.parse(message.toString());
      if (parsedMessage) {
        return new Message(parsedMessage.action, parsedMessage.payload);
      }
      throw "Invalid message";
    } catch (err) {
      LoggerHelper.logError(
        `An error had occurred while creating a message: ${err}`
      );
      return null;
    }
  }

  toString(): String {
    try {
      const array = {
        action: this.action,
        payload: this.payload,
      };
      return JSON.stringify(array);
    } catch (err) {
      LoggerHelper.logError(
        `An error had occurred while parsing the message: ${err}`
      );
    }
  }
}
