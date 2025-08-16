import moment from 'moment';
import { DateHelper } from './date-helper';

export class LoggerHelper {
	/**
	 *
	 * @param message
	 */
	public static logInfo(message: string): void {
		console.log('[INFO: ' + moment(DateHelper.now).format('DD-MM-YYYY hh:mm:ss') + '] ' + message);
	}
	/**
	 *
	 * @param message
	 */
	public static logError(message: string): void {
		console.log('[ERROR: ' + moment(DateHelper.now).format('DD-MM-YYYY hh:mm:ss') + '] ' + message);
	}
	/**
	 *
	 * @param message
	 */
	public static logWarn(message: string): void {
		console.log('[WARN: ' + moment(DateHelper.now).format('DD-MM-YYYY hh:mm:ss') + '] ' + message);
	}
}
