# frozen_string_literal: true
class SavedClaim::Pension < SavedClaim
  FORM = '21P-527EZ'
  CONFIRMATION = 'PEN'
  ATTACHMENT_KEYS = [:files].freeze
  PERSISTENT_CLASS = PersistentAttachment::PensionBurial

  def regional_office
    PensionBurial::ProcessingOffice.address_for(open_struct_form.veteranAddress.postalCode)
  end

  def attachment_keys
    self.class::ATTACHMENT_KEYS
  end
end
