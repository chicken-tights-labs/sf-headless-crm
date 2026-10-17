import { LightningElement, api, wire } from "lwc";
import getProfile from "@salesforce/apex/EPIC03_MemberProfile_Controller.getProfile";

export default class Epic03MemberProfile extends LightningElement {
  @api recordId;

  profile;
  error;

  @wire(getProfile, { memberId: "$recordId" })
  wiredProfile({ data, error }) {
    if (data) {
      this.profile = data;
      this.error = undefined;
    } else if (error) {
      this.profile = undefined;
      this.error = this.reduceError(error);
    } else {
      this.profile = undefined;
      this.error = undefined;
    }
  }

  get hasProfile() {
    return !!this.profile;
  }

  get showMedicalNotes() {
    return this.profile && this.profile.canViewMedicalNotes === true;
  }

  get medicalNotesDisplay() {
    if (!this.profile) {
      return "";
    }
    const notes = this.profile.medicalNotes;
    return notes && notes.trim() ? notes : "None on file";
  }

  get expiryDisplay() {
    if (!this.profile || !this.profile.expiryDate) {
      return "—";
    }
    return this.profile.expiryDate;
  }

  get tierDisplay() {
    if (!this.profile || !this.profile.membershipTier) {
      return "—";
    }
    return this.profile.membershipTier;
  }

  get statusDisplay() {
    if (!this.profile || !this.profile.status) {
      return "—";
    }
    return this.profile.status;
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
