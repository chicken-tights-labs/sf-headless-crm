# EPIC-04 / US-F007 — Apply Discount with Approval (implementation notes)

Issue: #61. Kanban: `t_2292b443`. Gherkin lives in the issue body. The issue names an Obsidian path. This file is the canonical copy.

## What exists

| Concern     | Implementation                                                                                                                                                                                                    |
| ----------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Staff UI    | Discount % and promo code on `epic04MerchandiseSale`. A PIN field appears only above 10%                                                                                                                          |
| Manager PIN | `epic04ManagerPin` on Home, visible when the user has custom permission `Manage_Merchandise_Discount`                                                                                                             |
| Stored PIN  | Private `Manager_Pin__c`, one row per user id in `User_Id__c` (text, because a User lookup cannot be unique or Restrict). `Pin_Hash__c` is SHA-256 of that id and the digits. No permission set can read the hash |
| Check       | `EPIC04_ManagerPin_Service` is `without sharing` and returns only the matching user id                                                                                                                            |
| Promo codes | `Promo_Code__c` with a required expiration date. Valid through that date. No usage limit. Inactive or expired codes are refused                                                                                   |
| 10% or less | No PIN. `Discount_Approved_By__c` is the staff user. Reason `Staff discount`                                                                                                                                      |
| Above 10%   | Manager PIN required. Approver is the manager whose PIN matched. Reason `Manager PIN`                                                                                                                             |
| Money       | Line items stay at shelf price. `Total_Amount__c` and the payment use the discounted total                                                                                                                        |

Why Apex: the front desk must not be able to read the PIN record, and the discount has to commit with the sale.

## Out of scope

Email or SMS approval. Usage limits on promo codes. Membership discounts. `Discount_Request__c` is not created.
