import { LightningElement, track, wire } from "lwc";
import createLead from "@salesforce/apex/EPIC04_LeadRegistration_Controller.createLead";
import getActiveLocations from "@salesforce/apex/EPIC04_LeadRegistration_Controller.getActiveLocations";
import convertForScreen from "@salesforce/apex/EPIC01_LeadConversion_Action.convertForScreen";

export const MSG_NO_LOCATIONS =
  "No active gym locations found. Ask an admin to add one.";
export const MSG_LOCATIONS_FAILED =
  "Could not load gym locations. Refresh the page and try again.";
export const MSG_NAME = "Enter a first and last name.";
export const MSG_LOCATION = "Pick a gym before creating the member.";
export const MSG_PROSPECT =
  "This member is Prospect until payment succeeds. Take payment only if they are paying now.";
export const MSG_LEAD_SAVED =
  "The walk-in lead was saved. Open the lead and use Convert to Member.";
export const MSG_PAYMENT_CLOSED =
  "Payment screen closed. Open the member to confirm Active or Prospect.";
export const PAYMENT_FLOW = "EPIC01_Process_Membership_Payment";

export default class Epic03TrainerNewMember extends LightningElement {
  @track firstName = "";
  @track lastName = "";
  @track phone = "";
  @track email = "";
  @track franchiseLocationId = "";
  @track message = "";
  @track error;
  @track locationOptions = [];
  @track locationsError;
  @track saving = false;
  @track memberId;
  @track showPayment = false;
  @track paymentInputs = [];
  @track paymentClosed = "";

  @wire(getActiveLocations)
  wiredLocations({ data, error }) {
    if (data) {
      this.locationOptions = data.map((location) => ({
        label: location.Name,
        value: location.Id
      }));
      this.locationsError = data.length ? undefined : MSG_NO_LOCATIONS;
    } else if (error) {
      this.locationOptions = [];
      this.locationsError = MSG_LOCATIONS_FAILED;
    }
  }

  get showForm() {
    return !this.memberId;
  }

  get prospectNote() {
    return MSG_PROSPECT;
  }

  get paymentFlow() {
    return PAYMENT_FLOW;
  }

  get memberUrl() {
    return this.memberId
      ? `/lightning/r/Member__c/${this.memberId}/view`
      : undefined;
  }

  handleFirstNameChange(event) {
    this.firstName = event.target.value;
  }

  handleLastNameChange(event) {
    this.lastName = event.target.value;
  }

  handlePhoneChange(event) {
    this.phone = event.target.value;
  }

  handleEmailChange(event) {
    this.email = event.target.value;
  }

  handleFranchiseLocationChange(event) {
    this.franchiseLocationId = event.detail.value;
  }

  handleCreate() {
    this.error = undefined;
    this.message = "";
    this.paymentClosed = "";

    if (!this.firstName || !this.lastName) {
      this.error = MSG_NAME;
      return;
    }
    if (!this.franchiseLocationId) {
      this.error = MSG_LOCATION;
      return;
    }

    this.saving = true;
    createLead({
      firstName: this.firstName,
      lastName: this.lastName,
      phone: this.phone,
      email: this.email,
      franchiseLocationId: this.franchiseLocationId
    })
      .then((leadId) => convertForScreen({ leadId }))
      .then((result) => {
        if (!result || !result.success) {
          this.error = `${(result && result.message) || "Could not convert the lead."} ${MSG_LEAD_SAVED}`;
          return;
        }
        this.memberId = result.memberId;
        this.message = result.message;
      })
      .catch((error) => {
        this.error = this.reduceError(error);
      })
      .finally(() => {
        this.saving = false;
      });
  }

  handleTakePayment() {
    this.paymentClosed = "";
    this.paymentInputs = [
      {
        name: "recordId",
        type: "String",
        value: this.memberId
      }
    ];
    this.showPayment = true;
  }

  handlePaymentStatus(event) {
    const status = event.detail && event.detail.status;
    if (status === "FINISHED" || status === "FINISHED_SCREEN") {
      this.showPayment = false;
      this.paymentClosed = MSG_PAYMENT_CLOSED;
    }
  }

  handleDone() {
    this.memberId = undefined;
    this.message = "";
    this.error = undefined;
    this.showPayment = false;
    this.paymentInputs = [];
    this.paymentClosed = "";
    this.firstName = "";
    this.lastName = "";
    this.phone = "";
    this.email = "";
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
