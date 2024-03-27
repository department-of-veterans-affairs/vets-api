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

    CentralMail::SubmitSavedClaimJob.new.perform(id)
  end

  def regional_office
    PensionBurial::ProcessingOffice.address_for(open_struct_form.claimantAddress.postalCode)
  end

  def attachment_keys
    %i[transportationReceipts deathCertificate].freeze
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

  def business_line
    'NCA'
  end
end
