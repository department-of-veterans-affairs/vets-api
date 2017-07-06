# frozen_string_literal: true
class SavedClaim::Burial < SavedClaim
  FORM = '21P-530'
  CONFIRMATION = 'PEN'
  PERSISTENT_CLASS = PersistentAttachment::PensionBurial

  def regional_office
    PensionBurial::ProcessingOffice.address_for(open_struct_form.claimantAddress.postalCode)
  end

  def attachment_keys
    [:transportationReceipts, :deathCertificate].freeze
  end
end
