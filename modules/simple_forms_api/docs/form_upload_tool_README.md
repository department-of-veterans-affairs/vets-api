# Form Upload Tool README

The Form Upload tool was developed by the Veteran Facing Forms team to provide an application where a Veteran can upload a PDF of their form. Their upload would travel through Lighthouse to the [Benefits Intake API](https://developer.va.gov/explore/api/benefits-intake/docs?version=current) and then along to Central Mail/VBMS. Currently, APIs other than the Benefits Intake API are not supported.

## Adding a new form to the Form Upload Tool

The Form Upload tool launched with support for four forms: `21-0779`, `21-509`, `21P-0518-1`, and `21P-0516-1`. If you'd like to add support for additional forms, follow the steps below.

### 1. Add the form to the prefill configuration

- Add an entry to [this array](https://github.com/department-of-veterans-affairs/vets-api/blob/master/app/models/form_profile.rb#L101-L108), appending `-UPLOAD` to the form id.

  **Why?**
  This enables prefill functionality for the form.

- Add a corresponding entry to [this hash](https://github.com/department-of-veterans-affairs/vets-api/blob/master/app/models/form_profile.rb#L127), similar to the existing configuration for `21-0779`.

  **Why?**
  This ensures the form is recognized for prefill.

### 2. Define the form’s expected page limits

- Add an entry to [this hash](https://github.com/department-of-veterans-affairs/vets-api/blob/master/app/models/persistent_attachments/va_form.rb#L11-L19), specifying:
  - The maximum expected number of pages.
  - The minimum number required for a valid submission.

  **Why?**
  This applies a **soft validation** which won’t block submission if incorrect, but it will display a confirmation alert prompting users to verify their uploaded file.

### 3. Integrate with VANotify to send notification emails (not required, but highly recommended)

- Add your form id to [this array](https://github.com/department-of-veterans-affairs/vets-api/blob/master/modules/simple_forms_api/app/services/simple_forms_api/notification/form_upload_email.rb#L15-L23).

  **Why?**
  This allows VANotify to send emails about the form submission. Three emails potentially get sent: once upon **submission**, and once each upon **error** or **receipt/final success**.

### 4. Follow the instructions in the `vets-website` repo

- [Follow the instructions here](https://github.com/department-of-veterans-affairs/vets-website/blob/main/src/applications/simple-forms/form-upload/README.md) to enable the form on the front-end.

  **Why?**
  The front end needs a few pieces of data to be able to accurately render the tool for additional forms.
