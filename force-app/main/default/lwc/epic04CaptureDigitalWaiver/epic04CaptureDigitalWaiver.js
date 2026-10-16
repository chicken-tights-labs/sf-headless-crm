import { LightningElement, api, wire } from "lwc";
import { CloseActionScreenEvent } from "lightning/actions";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getCaptureContext from "@salesforce/apex/EPIC04_WaiverCapture_Controller.getCaptureContext";
import captureWaiver from "@salesforce/apex/EPIC04_WaiverCapture_Controller.captureWaiver";

export const MSG_DRAW_REQUIRED = "Ask the visitor to sign on the pad.";

export default class Epic04CaptureDigitalWaiver extends LightningElement {
  @api recordId;

  signerName = "";
  signerEmail = "";
  signerRole = "Participant";
  templateId = "";
  templateOptions = [];
  locationName = "";
  displayName = "";
  recordType = "";
  contextError;
  saveError;
  message = "";
  saving = false;
  hasStroke = false;

  drawing = false;
  ctx;
  canvas;

  roleOptions = [
    { label: "Participant", value: "Participant" },
    { label: "Parent/Guardian", value: "Parent/Guardian" },
    { label: "Authorized Representative", value: "Authorized Representative" }
  ];

  @wire(getCaptureContext, { recordId: "$recordId" })
  wiredContext(result) {
    const { data, error } = result;
    if (data) {
      this.contextError = undefined;
      this.recordType = data.recordType;
      this.displayName = data.displayName;
      this.signerName = data.signerName || "";
      this.signerEmail = data.signerEmail || "";
      this.locationName = data.locationName || "";
      this.templateId = data.defaultTemplateId;
      this.templateOptions = (data.templates || []).map((t) => ({
        label: t.name + (t.templateType ? ` (${t.templateType})` : ""),
        value: t.id
      }));
    } else if (error) {
      this.contextError = this.reduceError(error);
    }
  }

  get heading() {
    return this.displayName
      ? `Capture waiver for ${this.displayName}`
      : "Capture Digital Waiver";
  }

  get isReady() {
    return !this.contextError && this.templateOptions.length > 0;
  }

  get saveDisabled() {
    return this.saving || !this.isReady;
  }

  renderedCallback() {
    if (!this.canvas && this.isReady) {
      this.canvas = this.template.querySelector('[data-id="signature-pad"]');
      if (this.canvas) {
        this.ctx = this.canvas.getContext("2d");
        if (this.ctx) {
          this.ctx.strokeStyle = "#111";
          this.ctx.lineWidth = 2;
          this.ctx.lineCap = "round";
          this.clearPadVisual();
        }
      }
    }
  }

  handleSignerName(event) {
    this.signerName = event.target.value;
  }

  handleSignerEmail(event) {
    this.signerEmail = event.target.value;
  }

  handleSignerRole(event) {
    this.signerRole = event.detail.value;
  }

  handleTemplate(event) {
    this.templateId = event.detail.value;
  }

  pointerPos(event) {
    const rect = this.canvas.getBoundingClientRect();
    const source = event.touches ? event.touches[0] : event;
    return {
      x: ((source.clientX - rect.left) / rect.width) * this.canvas.width,
      y: ((source.clientY - rect.top) / rect.height) * this.canvas.height
    };
  }

  handlePointerDown(event) {
    if (!this.ctx) {
      return;
    }
    event.preventDefault();
    this.drawing = true;
    const p = this.pointerPos(event);
    this.ctx.beginPath();
    this.ctx.moveTo(p.x, p.y);
  }

  handlePointerMove(event) {
    if (!this.drawing || !this.ctx) {
      return;
    }
    event.preventDefault();
    const p = this.pointerPos(event);
    this.ctx.lineTo(p.x, p.y);
    this.ctx.stroke();
    this.hasStroke = true;
  }

  handlePointerUp() {
    this.drawing = false;
  }

  clearPadVisual() {
    if (!this.ctx || !this.canvas) {
      return;
    }
    this.ctx.fillStyle = "#ffffff";
    this.ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);
    this.ctx.strokeStyle = "#111";
  }

  handleClear() {
    this.clearPadVisual();
    this.hasStroke = false;
    this.saveError = undefined;
  }

  handleCancel() {
    this.dispatchEvent(new CloseActionScreenEvent());
  }

  handleSave() {
    this.saveError = undefined;
    this.message = "";

    if (!this.hasStroke || !this.canvas) {
      this.saveError = MSG_DRAW_REQUIRED;
      return;
    }

    const dataUrl = this.canvas.toDataURL("image/png");
    this.saving = true;

    captureWaiver({
      recordId: this.recordId,
      signerName: this.signerName,
      signerEmail: this.signerEmail,
      signerRole: this.signerRole,
      templateId: this.templateId,
      signaturePngBase64: dataUrl
    })
      .then((result) => {
        if (!result.success) {
          this.saveError = result.message;
          return;
        }
        this.message = result.message;
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Waiver signed",
            message: result.message,
            variant: "success"
          })
        );
        this.dispatchEvent(new CloseActionScreenEvent());
      })
      .catch((error) => {
        this.saveError = this.reduceError(error);
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
