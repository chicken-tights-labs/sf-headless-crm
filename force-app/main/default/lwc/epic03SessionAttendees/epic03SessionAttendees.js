import { LightningElement, api, wire } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { refreshApex } from "@salesforce/apex";
import { getBarcodeScanner } from "lightning/mobileCapabilities";
import getAttendees from "@salesforce/apex/EPIC03_SessionAttendees_Controller.getAttendees";
import findByPhone from "@salesforce/apex/EPIC03_SessionAttendees_Controller.findByPhone";
import findByCode from "@salesforce/apex/EPIC03_SessionAttendees_Controller.findByCode";
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
  phoneInput = "";
  phoneMessage;
  phoneMatches = [];
  selectedBookingId;
  selectedMemberName;
  finding = false;
  codeInput = "";
  codeMessage;
  codeMatches = [];
  findingCode = false;
  scanAvailable = false;
  scanner;

  connectedCallback() {
    this.scanner = getBarcodeScanner();
    this.scanAvailable = Boolean(
      this.scanner && this.scanner.isAvailable && this.scanner.isAvailable()
    );
  }

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

  get hasPhoneMatches() {
    return this.phoneMatches && this.phoneMatches.length > 0;
  }

  get showPick() {
    return this.phoneMatches && this.phoneMatches.length > 1;
  }

  get canConfirm() {
    return Boolean(this.selectedBookingId);
  }

  get showSelectedLabel() {
    return this.showPick && Boolean(this.selectedMemberName);
  }

  handlePhoneChange(event) {
    this.phoneInput = event.target.value;
  }

  handleFind() {
    if (this.finding) {
      return;
    }
    this.phoneMessage = undefined;
    this.phoneMatches = [];
    this.selectedBookingId = undefined;
    this.selectedMemberName = undefined;
    this.finding = true;

    findByPhone({ sessionId: this.recordId, phone: this.phoneInput })
      .then((result) => {
        const matches = result && result.matches ? result.matches : [];
        if (!result || !result.validInput || matches.length === 0) {
          this.phoneMessage =
            result && result.message
              ? result.message
              : "No booking on this class matches that phone.";
          return;
        }
        this.phoneMatches = matches;
        if (matches.length === 1) {
          this.selectedBookingId = matches[0].bookingId;
          this.selectedMemberName = matches[0].memberName;
        }
      })
      .catch((error) => {
        this.phoneMessage = this.reduceError(error);
      })
      .finally(() => {
        this.finding = false;
      });
  }

  handlePick(event) {
    this.selectedBookingId = event.currentTarget.dataset.bookingId;
    this.selectedMemberName = event.currentTarget.dataset.memberName;
  }

  handleConfirm() {
    if (!this.selectedBookingId) {
      return;
    }
    this.doMarkAttended({
      bookingId: this.selectedBookingId,
      memberName: this.selectedMemberName
    });
  }

  get hasCodeMatches() {
    return this.codeMatches && this.codeMatches.length > 1;
  }

  handleCodeChange(event) {
    this.codeInput = event.target.value;
  }

  handleCodeCommit() {
    this.handleCodeSubmit();
  }

  handleScan() {
    if (!this.scanner || this.findingCode) {
      return;
    }
    const options = {
      barcodeTypes: [this.scanner.barcodeTypes.QR]
    };
    this.scanner
      .beginCapture(options)
      .then((barcode) => {
        this.codeInput = barcode && barcode.value ? barcode.value : "";
        this.handleCodeSubmit();
      })
      .catch((error) => {
        const code = error && error.code ? String(error.code) : "";
        if (code.toLowerCase().includes("dismiss")) {
          return;
        }
        this.codeMessage = this.reduceError(error);
      })
      .finally(() => {
        this.scanner.endCapture();
      });
  }

  handleCodePick(event) {
    this.doMarkAttended({
      bookingId: event.currentTarget.dataset.bookingId,
      memberName: event.currentTarget.dataset.memberName
    });
  }

  handleCodeSubmit() {
    if (this.findingCode) {
      return;
    }
    this.codeMessage = undefined;
    this.codeMatches = [];
    this.findingCode = true;

    findByCode({ sessionId: this.recordId, code: this.codeInput })
      .then((result) => {
        const matches = result && result.matches ? result.matches : [];
        if (!result || !result.validInput || matches.length === 0) {
          this.codeMessage =
            result && result.message
              ? result.message
              : "No booking on this class matches that code.";
          return;
        }
        if (matches.length === 1) {
          this.doMarkAttended({
            bookingId: matches[0].bookingId,
            memberName: matches[0].memberName
          });
          return;
        }
        this.codeMatches = matches;
        this.codeMessage = "Select the booking to check in.";
      })
      .catch((error) => {
        this.codeMessage = this.reduceError(error);
      })
      .finally(() => {
        this.findingCode = false;
      });
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
        this.phoneInput = "";
        this.phoneMessage = undefined;
        this.phoneMatches = [];
        this.selectedBookingId = undefined;
        this.selectedMemberName = undefined;
        this.codeInput = "";
        this.codeMessage = undefined;
        this.codeMatches = [];
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
