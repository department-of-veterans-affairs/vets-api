# frozen_string_literal: true
class SavedClaim::Burial < SavedClaim
  FORM = '21P-530'
  CONFIRMATION = 'PEN'
  PERSISTENT_CLASS = PersistentAttachment::PensionBurial
  ATTACHMENT_KEYS = [:transportationReceipts, :deathCertificate].freeze

  def regional_office
    PensionBurial::ProcessingOffice.address_for(open_struct_form.claimantAddress.postalCode)
  end
end
