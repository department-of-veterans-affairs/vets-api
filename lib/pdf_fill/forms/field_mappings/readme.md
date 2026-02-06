# PDF Field Mappings Generator

This directory contains field mapping files that define the relationship between form data and PDF field coordinates for VA forms. These mappings are used by the `PdfFill::Filler` system to populate PDF templates with veteran data.

## Generating Field Mappings

Use the `pdf:extract_fields` rake task to generate field mappings from PDF templates:

### Basic Usage

```bash
bundle exec rake pdf:extract_fields\[lib/pdf_fill/forms/pdfs/10-10EZ.pdf\]
```

This will create a JSON file with extracted field data at:

```
lib/pdf_fill/forms/10-10EZ_field_data.json
```

### Converting JSON to Ruby Mappings

The rake task generates a JSON file with basic field information. You'll need to manually convert this to the Ruby `KEY` structure used by the form classes:

1. **Run the extraction task**:

   ```bash
   bundle exec rake pdf:extract_fields[path/to/your-form.pdf]
   ```

2. **Review the generated JSON**:

   ```json
   [
     {
       "key": "F[0].P4[0].LastFirstMiddle[0]",
       "question_text": "VETERAN'S NAME",
       "options": null,
       "type": "text"
     }
   ]
   ```

3. **Create the Ruby mapping file** following the pattern in `lib/pdf_fill/forms/field_mappings/va1010ez.rb`:
   ```ruby
   module PdfFill
     module Forms
       module FieldMappings
         class Va1010ez
           KEY = {
             'veteranFullName' => {
               key: 'F[0].P4[0].LastFirstMiddle[0]',
               limit: 40,
               question_num: 1.01,
               question_text: "VETERAN'S NAME (Last, First, Middle Name)"
             }
           }.freeze
         end
       end
     end
   end
   ```

## Field Structure

Each field mapping contains:

- **`key`**: PDF field coordinate for a field. This is the only required key, but without the other keys the overflow page may not work as desired. (required)
- **`limit`**: Character limit for the field. This key is used to determine at what point a value for a field should go to the overflow page (optional)
- **`question_num`**: Form question number for reference. This key is used by the overflow page to determine question/answer order and is displayed with the `question_text`(optional)
- **`question_text`**: Human-readable field description used in the overflow page as the title (optional)
- **`question_suffix`**: Sub-question identifier like 'A', 'B' used in the overflow page title (optional)

## Prerequisites

- **pdftk** must be installed and configured in `Settings.binaries.pdftk`
- PDF template must have fillable form fields (not just text)
- PDF file must exist at the specified path

## Troubleshooting

### No fields extracted

```bash
# Check if PDF has form fields
pdftk your-form.pdf dump_data_fields
```

### Missing pdftk binary

Ensure pdftk is installed and the path is correctly set in `config/settings.yml`:

```yaml
binaries:
  pdftk: "/usr/local/bin/pdftk"
```

### Verifying generated mappings

Test your mapping in Rails console:

```ruby
mapping = PdfFill::Forms::FieldMappings::Va1010ez::KEY
mapping['veteranFullName']['key']  # Should return PDF field coordinate
```

## Integration

Once created, reference your mapping in the corresponding form class:

```ruby
class Va1010ez < FormBase
  FIELD_MAPPING = PdfFill::Forms::FieldMappings::Va1010ez::KEY
end
```
