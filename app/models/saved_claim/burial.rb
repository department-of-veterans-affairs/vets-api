# frozen_string_literal: true
class SavedClaim::Burial < SavedClaim
  FORM = '21P-530'
  def regional_office
    PensionBurial::ProcessingOffice.address_for(open_struct_form.claimantAddress.postalCode)
  end

  def confirmation_number
    "V-BUR-#{id}#{guid[0..6]}".upcase
  end
end
