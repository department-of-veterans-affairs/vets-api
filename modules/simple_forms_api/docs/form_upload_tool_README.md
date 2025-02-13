# Form Upload Tool README

The Form Upload tool was developed by the Veteran Facing Forms team to provide an application where a Veteran can upload a PDF of their form. Their upload would travel through Lighthouse to the [Benefits Intake API](https://developer.va.gov/explore/api/benefits-intake/docs?version=current) and then along to Central Mail/VBMS. Currently, APIs other than the Benefits Intake API are not supported.

## Adding a new form to the Form Upload Tool

The Form Upload tool launched with support for four forms: `21-0779`, `21-509`, `21P-0518-1`, and `21P-0516-1`. If you'd like to add support for additional forms, follow the steps below.

1. Add an entry to [this array](https://github.com/department-of-veterans-affairs/vets-api/blob/863dba2808abdca9b5484b5cd5e94dbdc3a124a4/app/models/form_profile.rb#L101), with the `-UPLOAD` suffix.

Explanation: Enables prefill.

2. Add a line similar to this one for `21-0779` to [this hash](https://github.com/department-of-veterans-affairs/vets-api/blob/863dba2808abdca9b5484b5cd5e94dbdc3a124a4/app/models/form_profile.rb#L120).

Explanation: Enables prefill.

3. Add an entry to [this hash](https://github.com/department-of-veterans-affairs/vets-api/blob/863dba2808abdca9b5484b5cd5e94dbdc3a124a4/app/models/persistent_attachments/va_form.rb#L11-L16).

Explanation: This indicates the maximum number of pages that we might expect from the form, and the minimum to be considered a complete form. This runs a loose validation that won't prevent submission on error, but will present the user with a confirmation alert, nudging them to confirm that they've uploaded the correct file.

4. Add your form id to [this array](https://github.com/department-of-veterans-affairs/vets-api/blob/863dba2808abdca9b5484b5cd5e94dbdc3a124a4/modules/simple_forms_api/app/services/simple_forms_api/form_upload_notification_email.rb#L14).

Explanation: This array will allow VANotify to send emails about the form submission. Three emails potentially get sent: once upon submission, and once each upon error or receipt/final success.

5. Follow the instructions in the `vets-website` repo to add support from the front end.

Explanation: The front end needs a few pieces of data to be able to accurately render the tool for additional forms.