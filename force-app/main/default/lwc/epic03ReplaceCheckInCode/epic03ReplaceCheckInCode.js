import { LightningElement, api, wire } from "lwc";
import currentCode from "@salesforce/apex/EPIC03_CheckInCode_Service.currentCode";
import replaceCode from "@salesforce/apex/EPIC03_CheckInCode_Service.replaceCode";

export default class Epic03ReplaceCheckInCode extends LightningElement {
  @api recordId;

  code;
  message;
  error;
  replacing = false;

  @wire(currentCode, { memberId: "$recordId" })
  wiredCode({ data, error }) {
    if (error) {
      this.error = this.reduceError(error);
      return;
    }
    if (data !== undefined) {
      this.code = data;
      this.error = undefined;
    }
  }

  get displayCode() {
    return this.code || "No check-in code yet.";
  }

  handleReplace() {
    if (this.replacing || !this.recordId) {
      return;
    }
    this.replacing = true;
    this.message = undefined;
    this.error = undefined;

    replaceCode({ memberId: this.recordId })
      .then((next) => {
        this.code = next;
        this.message = "The previous code no longer works.";
      })
      .catch((error) => {
        this.error = this.reduceError(error);
      })
      .finally(() => {
        this.replacing = false;
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
