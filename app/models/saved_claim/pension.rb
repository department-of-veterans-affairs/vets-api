# frozen_string_literal: true

require 'pension_burial/processing_office'

class SavedClaim::Pension < CentralMailClaim
  FORM = '21P-527EZ'

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
