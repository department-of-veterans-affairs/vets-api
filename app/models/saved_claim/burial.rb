# frozen_string_literal: true

class SavedClaim::Burial < CentralMailClaim
  FORM = '21P-530'
  PERSISTENT_CLASS = PersistentAttachments::PensionBurial

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
