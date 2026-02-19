---
name: va-form-upload-api
description: Add new forms to the VA Form Upload Tool backend (vets-api). Use when adding VA forms to the Form Upload system in the vets-api repository. Triggers include requests to add forms to Form Upload backend, enable VANotify emails, configure prefill/Save in Progress, or set up page limits.
---

# VA Form Upload Tool - Backend (vets-api)

## Workflow

When asked to add a form (e.g., "add form 20-10208 to form upload"):

### 1. Fetch and analyze the PDF

Fetch: `https://www.vba.va.gov/pubs/forms/VBA-{FORM-ID}-ARE.pdf`

Parse the PDF and determine:
- **Title**: From the form header (e.g., "DOCUMENT EVIDENCE SUBMISSION")
- **max-pages**: Total page count of the PDF
- **min-pages**: Count only pages with user-fillable fields (exclude instruction pages, mailing address pages, privacy act pages, or any page with no form fields). This is typically max-pages minus non-fillable pages.
- **Needs stamp?**: Look for "VA DATE STAMP" or "DO NOT WRITE IN THIS SPACE" box in top-right corner
- **Stamp page**: Which page has the stamp box (0-indexed)
- **Confirm with the User** Stop and ask the user if title, url, page count all look correct

### 1b. While we continue to work in vets api, also create a subagent task to run the VA-FORM-UPLOAD-WEB skill from the vets-website repo. Pass the required data for the script that it runs. It needs formId,title, and url

### 2. Continue in vets-api -> Save PDF as test fixture

Save the downloaded PDF to the fixtures directory for tests:

```bash
# Convert form ID: 20-10208 → vba_20_10208
# Save to: modules/simple_forms_api/spec/fixtures/pdfs/vba_{form_id_underscored}-completed.pdf

curl -o modules/simple_forms_api/spec/fixtures/pdfs/vba_20_10208-completed.pdf \
  "https://www.vba.va.gov/pubs/forms/VBA-20-10208-ARE.pdf"
```

Naming convention:
- Replace dashes with underscores in form ID
- Prefix with `vba_`
- Suffix with `-completed.pdf`
- Example: `20-10208` → `vba_20_10208-completed.pdf`

### 3. Run the script

```bash
ruby ~/.claude/skills/va-form-upload-api/scripts/add-form-upload.rb \
  --form-id={FORM_ID} \
  --title="{TITLE}" \
  --max-pages={TOTAL_PAGES} \
  --min-pages={FILLABLE_PAGES} \
  [--stamp --stamp-page={PAGE}]
```

### 4. Output includes Datadog widget JSON

Copy the JSON and add it to the Datadog dashboard manually.

## Script Options

| Option | Description |
|--------|-------------|
| `--form-id` | Form ID (required) |
| `--title` | Form title for Datadog widget |
| `--max-pages` | Maximum expected pages |
| `--min-pages` | Minimum expected pages |
| `--stamp` | Add if form has VA DATE STAMP box |
| `--stamp-page` | Page with stamp box (0-indexed) |

## Files Modified

- `app/models/form_profile.rb` — prefill config
- `app/models/persistent_attachments/va_form.rb` — page limits
- `modules/simple_forms_api/.../form_upload_email.rb` — VANotify
- `modules/simple_forms_api/.../scanned_form_stamps.rb` — stamps
- `modules/simple_forms_api/spec/fixtures/pdfs/vba_{form_id}-completed.pdf` — test fixture
