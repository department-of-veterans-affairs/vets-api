# frozen_string_literal: true
class SavedClaim::Pension < SavedClaim
  FORM = '21P-527EZ'
  def regional_office
    PensionBurial::ProcessingOffice.address_for(open_struct_form.veteranAddress.postalCode)
  end

  def confirmation_number
    "V-PEN-#{id}#{guid[0..6]}".upcase
  end
end
