# Persisent Attachment Remediation

## Context
On 6/11/25 there were changes made to `claim_documents_controller.rb` to remove `PensionBurial` from a conditional in place of a default `ClaimEvidence` model. In doing so,
KMS decryption got screwed up causing errors for pension and burial submissions. These errors occur when the process attempts to add the saved_claim_id to the `PersistentAttachment` model.
For more info, see [Burial Submission Failures](https://github.com/department-of-veterans-affairs/va.gov-team-sensitive/blob/master/Postmortems/2025/2025-06-11_Burial_Submission_Failures.md)

## Recognize the Error
In the `benefits-pension-burial-notifications`, if you see something along the lines of "Triggered: Benefits 21P-527EZ Pension Metric pensions/v0/claims 500 error >=3" then you'll want to do the steps below

### Step 1 - DataDog
You'll want to locate the claim_id associated with the failing attachment. Navigate to the Burial or Pension Controller dashboard and
look under "Burial orPensionClaimsController Events". Click one and navgiate in the menu to "Logs". Then click on the one that says
"Pensions::Monitor 21P-527EZ process attachment error", this will open up a side window and if you scroll down you'll find the
claim_id under the payload

### Step 2 - Remediate
There is a rake task that you can run to put in the claim_id and it will loop over the claim's attachment key GUIDS
and remove any attachments that are missing a saved_claim_id or cause a KMS decryption error. If true, the bad attachments are deleted as well as the claim

`❯ bundle exec rake persistent_attachment_remediation:run[claim_id_here]`
