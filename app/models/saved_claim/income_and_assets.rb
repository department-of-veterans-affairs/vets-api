# frozen_string_literal: true

require 'pension_burial/processing_office'

class SavedClaim::IncomeAndAssets < SavedClaim
  FORM = '21P-0969'

  def regional_office
    ['REGIONAL_OFFICE TBD']
  end

  def attachment_keys
    [:files].freeze
  end
end
