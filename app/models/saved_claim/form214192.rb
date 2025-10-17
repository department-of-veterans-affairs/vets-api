# frozen_string_literal: true

class SavedClaim::Form214192 < SavedClaim
  FORM = '21-4192'

  validates :form_data, presence: true
  validates_with Form214192Validator

  def process_attachments!
    refs = attachment_keys.map { |key| Array(open_struct_form.send(key)) }.flatten
    files = PersistentAttachment.where(guid: refs.map(&:confirmationCode))
    files.find_each { |f| f.update(saved_claim_id: id) }

    Lighthouse::SubmitBenefitsIntakeClaim.perform_async(id)
  end

  def send_confirmation_email
    # Email functionality not included in MVP
    # employer_email = parsed_form.dig('employmentInformation', 'employerEmail')
    # return unless employer_email

    # VANotify::EmailJob.perform_async(
    #   employer_email,
    #   Settings.vanotify.services.va_gov.template_id.form214192_confirmation,
    #   {
    #     'employer_name' => employer_name,
    #     'veteran_name' => veteran_name,
    #     'confirmation_number' => confirmation_number,
    #     'date_submitted' => created_at.strftime('%B %d, %Y')
    #   }
    # )
  end

  # SavedClaims require regional_office to be defined
  def regional_office
    []
  end

  # Required for Lighthouse Benefits Intake API submission
  # CMP = Compensation (for disability claims)
  def business_line
    'CMP'
  end

  # VBMS document type for employment information
  def document_type
    119 # Request for Employment Information
  end

  def attachment_keys
    [:supportingDocuments].freeze
  end

  private

  def employer_name
    parsed_form.dig('employmentInformation', 'employerName') || 'Employer'
  rescue
    'Employer'
  end

  def veteran_name
    "#{parsed_form.dig('veteranInformation', 'fullName',
                       'first')} #{parsed_form.dig('veteranInformation', 'fullName', 'last')}"
  rescue
    'Veteran'
  end
end
