import { LightningElement, track, wire } from "lwc";
import createLead from "@salesforce/apex/EPIC04_LeadRegistration_Controller.createLead";
import getActiveLocations from "@salesforce/apex/EPIC04_LeadRegistration_Controller.getActiveLocations";

export const MSG_NO_LOCATIONS =
  "No active gym locations found. Ask an admin to add one.";
export const MSG_LOCATIONS_FAILED =
  "Could not load gym locations. Refresh the page and try again.";

export default class Epic04LeadRegistrationForm extends LightningElement {
  @track firstName = "";
  @track lastName = "";
  @track phone = "";
  @track email = "";
  @track franchiseLocationId = "";
  @track message = "";
  @track error;
  @track locationOptions = [];
  @track locationsError;

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

  handleRegisterLead() {
    this.error = undefined;
    this.message = "";

    createLead({
      firstName: this.firstName,
      lastName: this.lastName,
      phone: this.phone,
      email: this.email,
      franchiseLocationId: this.franchiseLocationId
    })
      .then((result) => {
        this.message = "Lead registered successfully! Lead ID: " + result;
        // Location stays selected: front desk registers walk-ins for their own gym.
        this.firstName = "";
        this.lastName = "";
        this.phone = "";
        this.email = "";
      })
      .catch((error) => {
        this.error = error.body.message;
      });
  }
}
