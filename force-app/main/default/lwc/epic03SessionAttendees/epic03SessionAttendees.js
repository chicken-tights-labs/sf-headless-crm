import { LightningElement, api, wire } from "lwc";
import getAttendees from "@salesforce/apex/EPIC03_SessionAttendees_Controller.getAttendees";

export const COLUMNS = [
  { label: "Member", fieldName: "memberName", type: "text" },
  { label: "Check-in", fieldName: "checkInStatus", type: "text" },
  { label: "Waiver", fieldName: "waiverStatus", type: "text" },
  { label: "Booking status", fieldName: "bookingStatus", type: "text" }
];

export default class Epic03SessionAttendees extends LightningElement {
  @api recordId;

  columns = COLUMNS;
  attendees = [];
  error;

  @wire(getAttendees, { sessionId: "$recordId" })
  wiredAttendees(result) {
    const { data, error } = result;
    if (data) {
      this.attendees = data;
      this.error = undefined;
    } else if (error) {
      this.attendees = [];
      this.error = this.reduceError(error);
    }
  }

  get hasRows() {
    return this.attendees && this.attendees.length > 0;
  }

  get isEmpty() {
    return !this.error && this.attendees && this.attendees.length === 0;
  }

  get countLabel() {
    const n = this.attendees ? this.attendees.length : 0;
    return n === 1 ? "1 attendee" : `${n} attendees`;
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
