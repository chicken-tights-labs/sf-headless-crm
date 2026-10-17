import { LightningElement, api, wire } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { refreshApex } from "@salesforce/apex";
import getAttendees from "@salesforce/apex/EPIC03_SessionAttendees_Controller.getAttendees";
import markAttended from "@salesforce/apex/EPIC03_SessionAttendees_Controller.markAttended";

const ACTIONS = [{ label: "Mark Attended", name: "mark_attended" }];

export const COLUMNS = [
  {
    label: "Member",
    fieldName: "memberUrl",
    type: "url",
    typeAttributes: {
      label: { fieldName: "memberName" },
      target: "_self"
    }
  },
  { label: "Check-in", fieldName: "checkInStatus", type: "text" },
  { label: "Waiver", fieldName: "waiverStatus", type: "text" },
  { label: "Booking status", fieldName: "bookingStatus", type: "text" },
  {
    type: "action",
    typeAttributes: {
      rowActions: ACTIONS,
      menuAlignment: "right"
    }
  }
];

export default class Epic03SessionAttendees extends LightningElement {
  @api recordId;

  columns = COLUMNS;
  attendees = [];
  error;
  actionError;
  saving = false;
  wiredResult;

  @wire(getAttendees, { sessionId: "$recordId" })
  wiredAttendees(result) {
    this.wiredResult = result;
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

  handleRowAction(event) {
    const action = event.detail.action;
    const row = event.detail.row;
    if (action.name === "mark_attended") {
      this.doMarkAttended(row);
    }
  }

  doMarkAttended(row) {
    if (this.saving || !row || !row.bookingId) {
      return;
    }
    this.actionError = undefined;
    this.saving = true;

    markAttended({ bookingId: row.bookingId })
      .then((result) => {
        if (!result.success) {
          this.actionError = result.message;
          this.dispatchEvent(
            new ShowToastEvent({
              title: "Check-in blocked",
              message: result.message,
              variant: "error"
            })
          );
          return Promise.resolve();
        }
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Checked in",
            message: row.memberName
              ? `${row.memberName} marked attended.`
              : result.message,
            variant: "success"
          })
        );
        return refreshApex(this.wiredResult);
      })
      .catch((error) => {
        this.actionError = this.reduceError(error);
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Check-in failed",
            message: this.actionError,
            variant: "error"
          })
        );
      })
      .finally(() => {
        this.saving = false;
      });
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
