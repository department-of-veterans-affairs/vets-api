# frozen_string_literal: true

class SavedClaim::Pension < SavedClaim
  FORM = '21P-527EZ'
  CONFIRMATION = 'PEN'
  PERSISTENT_CLASS = PersistentAttachments::PensionBurial

  def regional_office
    PensionBurial::ProcessingOffice.address_for(open_struct_form.veteranAddress.postalCode)
  end

  def attachment_keys
    [:files].freeze
  end

  def email
    parsed_form['email']
  end
end
