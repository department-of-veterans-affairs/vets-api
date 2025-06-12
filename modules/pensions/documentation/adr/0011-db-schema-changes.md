# 10. Database changes to support BPDS and Lighthouse Form Submissions

Date: 2025-03-17

## Status

Proposed

## Context

The Pension and Burial Team has been asked to integrate with a new back-end system called BPDS (Benefits Process Data Service) which is used as a central repository for JSON versions of scanned VA forms.  To store the form submission data and associated metadata, our team proposes that we create new tables and models that support not only this new initiative, but standardizes the changes for form submissions to Lighthouse, RES, or other back-end systems.  This greenfield work allows us to be more flexible and to be less constrained by legacy decisions.  

#### **Code quality**
In doing this work, there is an opportunity to improve the database structure and code quality for the Lighthouse Submissions.  Our current database schema utilizes shared code across multiple teams, sometimes with differing approaches and unnecessary bloat.   Our changes are an attempt to standardize and streamline the models that represent the data, without including form specific business logic in the models.   For example, within the `form_submission_attempt`, there are multiple examples of code that do not represent models, but rather are jobs being kicked off from within a model.  
- [queue_form526_form4142_email](https://github.com/department-of-veterans-affairs/vets-api/blob/master/app/models/form_submission_attempt.rb#L116)
- [form526_form4142_email](https://github.com/department-of-veterans-affairs/vets-api/blob/master/app/models/form_submission_attempt.rb#L106)
- [simple_forms_enqueue_result_email](https://github.com/department-of-veterans-affairs/vets-api/blob/master/app/models/form_submission_attempt.rb#L140)
- [should_send_simple_forms_email](https://github.com/department-of-veterans-affairs/vets-api/blob/master/app/models/form_submission_attempt.rb#L136C7-L136C37)

There are also references to [CentralMail::SubmitForm4142Job](https://github.com/department-of-veterans-affairs/vets-api/blob/master/app/models/form_submission_attempt.rb#L128), which is deprecated but remains in the model.

#### Back-end services tied to their own specific tables
Our intention is to separate back-end tables so that they represent the downstream services they utilize.  Instead of trying to make the existing `form_submission` and `form_submission_attempts` tables contort to each downstream service, our schema separates them, giving us greater flexibility.  In creating new LighthouseSubmission and LighthouseSubmissionAttempt tables, we are moving away from existing tables with ambiguous fields and shared purposes. 

#### Precedent
This ADR doesn't represent a substantial change when viewed as a whole against the current vets-api schema.  There are already nearly a dozen other form specific tables in [vets-api](https://github.com/department-of-veterans-affairs/vets-api/blob/master/db/schema.rb).  For example, the 526 team uses their own structure to represent back-end services that are unique to their form, which is perfectly reasonable.  
- lighthouse526_document_uploads
- form526_submissions
- form526_submission_remediations
- form526_job_statuses

This ADR just builds on this approach by tying it to specific services that we connect to downstream.

## Alternatives
If this ADR is not accepted, we will need to pursue an alternative path of modifying the existing `Form_Submission` and `Form_Submission_Attempt` tables.  Right now, these tables do not allow for the paradigm of having a form going to different back-end systems.  So, for example, if you were to submit a form for VR&E, you might be sending to RES, you might be sending to Lighthouse, or perhaps you would be using BIP claims.  The current structure of the tables doesn't track or break out attempts for those downstream services. 

In order to handle multiple submission pathways using existing tables, the tables will require additional added complexity. Just to support BPDS, we would need to add additional fields, including a BPDS id and reference data. These columns would require validation, but because the required columns are only present for BPDS, this will be complex and potentially unreliable. These columns would also be null for all but BPDS submissions, meaning that a great deal of unused database memory would be required for the benefit of only a small percentage of submissions. 

The associated models would also require special handling to be added in order to process submissions for additional submission pathways. For example, the statuses associated with Lighthouse Benefit Intake submissions would not necessarily translate to BPDS, requiring additional complexity for the submission state handlers.
In addition, attempting to add all submissions to a single set of tables will cause an increase in the length of time required to query submissions, taking additional time for database requests.  

Additionally, the FormSubmissionAttempts model is tightly coupled to the simple forms API, which has caused issues and conflicts in the past when we tried to modify code that is shared with simple forms. Since our pension application does not use simple forms, we've had to create duplicative logic and workarounds to navigate around simple forms API logic. Also, the status state machine flow is statically defined with the assumption that all submission flows will be identical. But in the case of BPDS submissions, we won't be following that pre-defined pattern so we would have to do a lot of extending and overriding of logic to make it fit for our needs.

Our approach would be to modify these tables and their respective models to use Single Table Inheritance (STI).  STI would allow for subclasses to share common attributes and for easier querying.  However, this could potentially be quite disruptive change since the code is shared across multiple teams.  There is no guarantee of buy-in or VA-wide adoption of this effort.


## Decision
The proposed structure for our change is:
https://github.com/department-of-veterans-affairs/vets-api/pull/21205

![image](https://github.com/user-attachments/assets/e6304a45-fcab-4dc5-8300-a1f302612e7f)

This ADR proposes a path forward to allow the greatest flexibility for our team with minimal impact to other teams.  There will undoubtedly be concerns raised about duplication of code and tables.  Making common, reusable code, has been a major theme of our work on this team and this ADR sets a new pattern that can be extended to other forms and to other teams.  

For more reading on this:
- https://medium.com/@nlsnboa/understanding-single-table-inheritance-a-simplified-approach-94ce620c58ae
- https://guides.rubyonrails.org/association_basics.html

