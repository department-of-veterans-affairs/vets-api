# frozen_string_literal: true

require 'pension_burial/processing_office'

class SavedClaim::Burial < CentralMailClaim
  FORM = '21P-530'

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
end
