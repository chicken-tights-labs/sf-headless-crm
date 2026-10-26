# EPIC-04 / US-F006 — Process Merchandise Sale (implementation notes)

Issue: #60. Kanban: `t_cc2cae33`. Gherkin lives in the issue body. The issue names `CRM-Documentation/EPIC-04_US-F006_Process_Merchandise_Sale.md`. This file is the canonical copy. Sync the vault from it when the vault is available.

## What exists

| Concern    | Implementation                                                                                                      |
| ---------- | ------------------------------------------------------------------------------------------------------------------- |
| Staff UI   | `epic04MerchandiseSale` on Gym Manager Home, under Walk-In Lead Registration                                        |
| Sale       | `EPIC04_MerchandiseSale_Controller.completeSale` inserts `Merchandise_Sale__c` and one `Sale_Line_Item__c` per item |
| Price      | Copied from `Inventory_Item__c.Unit_Price__c`. The screen does not accept a typed price                             |
| Stock      | `Current_Stock__c` decremented in the same transaction. Oversell rolls the sale back                                |
| Payment    | `Payment_Transaction__c`, type Merchandise Purchase, status Completed. Sale method Card is stored as Credit Card    |
| Not called | `EPIC01_ProcessPayment_Action` / `processPayment` (that path activates a membership)                                |

Why Apex and LWC: a screen flow cannot keep a cart, lock stock, and insert the header, lines, and payment as one transaction.

## Out of scope

Discounts (#61) and refunds (#62). Discount fields on the sale stay blank.
