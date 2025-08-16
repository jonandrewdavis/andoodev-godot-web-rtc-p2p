import moment, { Moment } from "moment";

export class DateHelper {
  /**
   *
   */
  public static get today(): Date {
    return new Date(moment().toString().slice(0, 10) + "T00:00:00");
  }

  /**
   *
   */
  public static get now(): Date {
    return new Date(moment().toString());
  }
  /**
   *
   * @param date
   * @param days
   * @returns
   */
  public static addDays(date: Date, days: number): Date {
    const result: Date = new Date(date);
    result.setDate(result.getDate() + days);
    return result;
  }

  /**
   *
   * @param date
   * @param days
   * @returns
   */
  public static addMinutes(date: Date, minutes: number): Date {
    const result: Date = new Date(date);
    result.setMinutes(result.getMinutes() + minutes);
    return result;
  }

  /**
   * Varifica che una data Stringa abbia un formato data valido
   * @param value
   * @param format
   */
  public static validate(value: string, format: string): boolean {
    try {
      const date: Moment = moment(value, format, true);
      return date.isValid();
    } catch (error: unknown) {
      return false;
    }
  }

  /**
   * Ritorna la differenza di due date in minuti
   * @param startDate Data di inizio
   * @param endDate Data di fine
   * @returns durata in minuti
   */
  public static getMinutesDuration(startDate: Date, endDate: Date): number {
    try {
      return moment
        .duration(moment(endDate).diff(moment(startDate)))
        .asMinutes();
    } catch (error: unknown) {
      return 0;
    }
  }

  /**
   * Ritorna la differenza di due date in secondi
   * @param startDate Data di inizio
   * @param endDate Data di fine
   * @returns durata in secondi
   */
  public static getSecondsDuration(startDate: Date, endDate: Date): number {
    try {
      return Math.round(
        moment.duration(moment(endDate).diff(moment(startDate))).asSeconds()
      );
    } catch (error: unknown) {
      return 0;
    }
  }
}
