# frozen_string_literal: true

require 'pension_burial/processing_office'

class SavedClaim::IncomeAndAssets < SavedClaim
  FORM = '21P-0969'

  ##
  # the predefined regional office address
  #
  # @return [Array<String>] the address lines of the regional office
  #
  def regional_office
    ['Department of Veteran Affairs',
     'Pension Intake Center',
     'P.O. Box 5365',
     'Janesville, Wisconsin 53547-5365']
  end

  ##
  # send this Income and Assets Evidence claim to the Lighthouse Benefit Intake API
  #
  # @see https://developer.va.gov/explore/api/benefits-intake/docs
  #
  # @param current_user [User] the current user submitting the form
  #
  def upload_to_lighthouse(current_user = nil)
    return unless Flipper.enabled?(:pension_income_and_assets_clarification, current_user)

    Lighthouse::IncomeAndAssetsIntakeJob.perform_async(id, current_user&.user_account_uuid)
  end
end
