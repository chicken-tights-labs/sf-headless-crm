import { LightningElement, track } from "lwc";
import canManagePins from "@salesforce/apex/EPIC04_ManagerPin_Service.canManagePins";
import setMyPin from "@salesforce/apex/EPIC04_ManagerPin_Service.setMyPin";

export default class Epic04ManagerPin extends LightningElement {
  @track allowed = false;
  @track pin = "";
  @track message = "";
  @track error;

  connectedCallback() {
    canManagePins()
      .then((allowed) => {
        this.allowed = allowed === true;
      })
      .catch(() => {
        this.allowed = false;
      });
  }

  handlePinChange(event) {
    this.pin = event.target.value;
  }

  handleSave() {
    this.message = "";
    this.error = undefined;
    setMyPin({ pin: this.pin })
      .then(() => {
        this.message = "PIN saved.";
        this.pin = "";
      })
      .catch((err) => {
        this.error =
          err && err.body && err.body.message
            ? err.body.message
            : "Could not save the PIN.";
      });
  }
}
