# EPIC-04 / US-F008 — Merchandise refund (implementation notes)

Issue: #62. Kanban: `t_e22d7ba3`. Gherkin lives in the issue body. The issue names `CRM-Documentation/EPIC-04_US-F008_Process_Refund_Return.md`. This file is the canonical copy. Sync the vault from it when the vault is available.

## What exists

| Concern    | Implementation                                                                                                                                                                                                                                     |
| ---------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Staff UI   | **Refund** on the Merchandise Sale record. Open the sale from the App Launcher (Merchandise Sales is not on the Boxing Gym CRM tab bar).                                                                                                           |
| Reason     | Required. Stored on `Merchandise_Sale__c.Refund_Reason__c`. No manager PIN.                                                                                                                                                                        |
| Sale       | `Status__c` becomes Refunded. A blank status (sales created before this field) can still be refunded once.                                                                                                                                         |
| Stock      | Sold quantity is added back to `Inventory_Item__c.Current_Stock__c` in the same transaction.                                                                                                                                                       |
| Payment    | New `Payment_Transaction__c`, type Refund, status Completed, positive amount equal to `Total_Amount__c` (the amount paid, after any discount). Card on the sale is stored as Credit Card. `Merchandise_Sale__c` on the payment points at the sale. |
| Left alone | The original Merchandise Purchase row stays Completed. Membership status, dates, welcome email, and referral are not changed. `processPayment` is not called.                                                                                      |

Why Apex: the sale status, stock return, and refund payment must commit or roll back together. The screen flow only collects the reason and calls `EPIC04_MerchandiseRefund_Action`.

## Out of scope

Partial refunds. Membership refunds. A card-processor refund. A second refund of the same sale.
