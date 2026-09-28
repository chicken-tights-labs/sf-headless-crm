import { LightningElement, track } from 'lwc';
import createLead from '@salesforce/apex/EPIC04_LeadRegistration_Controller.createLead';

export default class Epic04LeadRegistrationForm extends LightningElement {
    @track firstName = '';
    @track lastName = '';
    @track phone = '';
    @track email = '';
    @track franchiseLocationId = '';
    @track message = '';
    @track error;

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
        this.franchiseLocationId = event.target.value;
    }

    handleRegisterLead() {
        this.error = undefined;
        this.message = '';

        createLead({
            firstName: this.firstName,
            lastName: this.lastName,
            phone: this.phone,
            email: this.email,
            franchiseLocationId: this.franchiseLocationId
        })
        .then(result => {
            this.message = 'Lead registered successfully! Lead ID: ' + result;
            // Clear form fields
            this.firstName = '';
            this.lastName = '';
            this.phone = '';
            this.email = '';
        })
        .catch(error => {
            this.error = error.body.message;
        });
    }
}