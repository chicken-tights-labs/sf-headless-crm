import { LightningElement, wire } from "lwc";
import getMyWeekSessions from "@salesforce/apex/EPIC03_TrainerSchedule_Controller.getMyWeekSessions";

export const COLUMNS = [
  {
    label: "Class",
    fieldName: "sessionUrl",
    type: "url",
    typeAttributes: {
      label: { fieldName: "sessionName" },
      target: "_self"
    }
  },
  {
    label: "Start",
    fieldName: "startTime",
    type: "date",
    typeAttributes: {
      year: "numeric",
      month: "short",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit"
    }
  },
  { label: "Location", fieldName: "locationName", type: "text" },
  { label: "Booked", fieldName: "bookedCount", type: "number" },
  { label: "Capacity", fieldName: "capacity", type: "number" }
];

export default class Epic03TrainerSchedule extends LightningElement {
  columns = COLUMNS;
  sessions = [];
  error;

  @wire(getMyWeekSessions)
  wiredSessions(result) {
    const { data, error } = result;
    if (data) {
      this.sessions = data;
      this.error = undefined;
    } else if (error) {
      this.sessions = [];
      this.error = this.reduceError(error);
    }
  }

  get hasRows() {
    return this.sessions && this.sessions.length > 0;
  }

  get isEmpty() {
    return !this.error && this.sessions && this.sessions.length === 0;
  }

  get countLabel() {
    const n = this.sessions ? this.sessions.length : 0;
    return n === 1 ? "1 class this week" : `${n} classes this week`;
  }

  reduceError(error) {
    if (!error) {
      return "Unknown error";
    }
    if (Array.isArray(error.body)) {
      return error.body.map((e) => e.message).join(", ");
    }
    if (error.body && typeof error.body.message === "string") {
      return error.body.message;
    }
    return error.message || "Unknown error";
  }
}
