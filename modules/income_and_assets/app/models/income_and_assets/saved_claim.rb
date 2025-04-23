# frozen_string_literal: true

require 'income_and_assets/benefits_intake/benefit_intake_job'

module IncomeAndAssets
  # IncomeAndAssets 21P-0969 Active::Record
  # @see app/model/saved_claim
  class SavedClaim < ::SavedClaim
    # Income and Assets Form ID
    FORM = IncomeAndAssets::FORM_ID

    # the predefined regional office address
    #
    # @return [Array<String>] the address lines of the regional office
    def regional_office
      ['Department of Veteran Affairs',
       'Pension Intake Center',
       'P.O. Box 5365',
       'Janesville, Wisconsin 53547-5365']
    end

    # utility function to retrieve claimant email from form
    #
    # @return [String] the claimant email
    def email
      # parsed_form['email'] # TODO add email field to the form
      'test@example.com'
    end

    # Utility function to retrieve veteran first name from form
    #
    # @return [String]
    def first_name
      parsed_form.dig('veteranFullName', 'first')
    end
  end
end
