# frozen_string_literal: true

require 'pension_burial/processing_office'

class SavedClaim::Burial < CentralMailClaim
  FORM = '21P-530'

  # attribute name is passed from the FE as a flag, maintaining camel case
  attr_accessor :formV2 # rubocop:disable Naming/MethodName

  after_initialize do
    self.form_id = if Flipper.enabled?(:va_burial_v2)
                     formV2 || form_id == '21P-530V2' ? '21P-530V2' : self.class::FORM.upcase
                   else
                     self.class::FORM.upcase
                   end
  end

  def process_attachments!
    refs = attachment_keys.map { |key| Array(open_struct_form.send(key)) }.flatten
    files = PersistentAttachment.where(guid: refs.map(&:confirmationCode))
    files.find_each { |f| f.update(saved_claim_id: id) }
  end

  def regional_office
    PensionBurial::ProcessingOffice.address_for(open_struct_form.claimantAddress.postalCode)
  end

  def attachment_keys
    %i[transportationReceipts deathCertificate militarySeparationDocuments additionalEvidence].freeze
  end

  def email
    parsed_form['claimantEmail']
  end

  def form_matches_schema
    return unless form_is_string

    JSON::Validator.fully_validate(VetsJsonSchema::SCHEMAS[form_id], parsed_form).each do |v|
      errors.add(:form, v.to_s)
    end
  end

  def process_pdf(pdf_path, timestamp = nil, form_id = nil)
    processed_pdf = PDFUtilities::DatestampPdf.new(pdf_path).run(
      text: 'Application Submitted on va.gov',
      x: 400,
      y: 675,
      text_only: true, # passing as text only because we override how the date is stamped in this instance
      timestamp:,
      page_number: 6,
      template: "lib/pdf_fill/forms/pdfs/#{form_id}.pdf",
      multistamp: true
    )
    renamed_path = "tmp/pdfs/#{form_id}_#{id}_final.pdf"
    File.rename(processed_pdf, renamed_path) # rename for vbms upload
    renamed_path # return the renamed path
  end

  def business_line
    'NCA'
  end

  def send_confirmation_email
    return if parsed_form['claimantEmail'].blank?

    facility_name, street_address, city_state_zip = regional_office
    first_name = parsed_form.dig('veteranFullName', 'first')
    last_initial = "#{parsed_form.dig('veteranFullName', 'last')&.first}."

    VANotify::EmailJob.perform_async(
      parsed_form['claimantEmail'],
      Settings.vanotify.services.va_gov.template_id.burial_claim_confirmation_email_template_id,
      {
        'form_name' => 'Burial Benefit Claim (Form 21P-530)',
        'confirmation_number' => guid,
        'deceased_veteran_first_name_last_initial' => "#{first_name} #{last_initial}",
        'benefits_claimed' => benefits_claimed,
        'facility_name' => facility_name,
        'street_address' => street_address,
        'city_state_zip' => city_state_zip,
        'first_name' => parsed_form.dig('claimantFullName', 'first')&.upcase.presence,
        'date_submitted' => Time.zone.today.strftime('%B %d, %Y')
      }
    )
  end

  def benefits_claimed
    claimed = []
    claimed << 'Burial Allowance' if parsed_form['burialAllowance']
    claimed << 'Plot Allowance' if parsed_form['plotAllowance']
    claimed << 'Transportation' if parsed_form['transportation']
    " - #{claimed.join(" \n - ")}"
  end
end
