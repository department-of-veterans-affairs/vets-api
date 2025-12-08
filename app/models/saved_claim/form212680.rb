# frozen_string_literal: true

class SavedClaim::Form212680 < SavedClaim
  FORM = '21-2680'

  # Regional office information for Pension Management Center
  def regional_office
    [
      'Department of Veterans Affairs',
      'Pension Management Center',
      'P.O. Box 5365',
      'Janesville, WI 53547-5365'
    ]
  end

  # Business line for VA processing
  def business_line
    'PMC' # Pension Management Center
  end

  # VBMS document type for Aid and Attendance/Housebound
  # Note: This form can be used as either:
  # - Supporting documentation for an existing pension claim (most common)
  # - A primary claim form for A&A/Housebound benefits (some cases)
  def document_type
    540 # Aid and Attendance/Housebound
  end

  # Generate pre-filled PDF with veteran sections
  def generate_prefilled_pdf
    pdf_path = to_pdf

    # Update metadata to track PDF generation
    update_metadata_with_pdf_generation

    pdf_path
  end

  # Get PDF download instructions
  def download_instructions
    {
      title: 'Next Steps: Get Physician to Complete Form',
      steps: [
        'Download the pre-filled PDF below',
        'Print the PDF or save it to your device',
        'Take the form to your physician',
        'Have your physician complete Sections VI-VIII',
        'Have your physician sign Section VIII',
        'Scan or photograph the completed form',
        'Upload the completed form at: va.gov/upload-supporting-documents'
      ],
      upload_url: "#{Settings.hostname}/upload-supporting-documents",
      form_number: '21-2680',
      regional_office: regional_office.join(', ')
    }
  end

  # Attachment keys (not used in this workflow, but required by SavedClaim)
  def attachment_keys
    [].freeze
  end

  # Override to_pdf to add veteran signature stamp
  def to_pdf(file_name = nil, fill_options = {})
    pdf_path = PdfFill::Filler.fill_form(self, file_name, fill_options)
    PdfFill::Forms::Va212680.stamp_signature(pdf_path, parsed_form)
  end

  def veteran_first_last_name
    full_name = parsed_form.dig('veteranInformation', 'fullName')
    return 'Veteran' unless full_name.is_a?(Hash)

    "#{full_name['first']} #{full_name['last']}"
  end

  private

  def update_metadata_with_pdf_generation
    current_metadata = metadata.present? ? JSON.parse(metadata) : {}
    current_metadata['pdf_generated_at'] = Time.current.iso8601
    current_metadata['submission_method'] = 'print_and_upload'

    self.metadata = current_metadata.to_json
    save!(validate: false)
  end
end
