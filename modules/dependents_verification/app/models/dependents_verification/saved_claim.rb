# frozen_string_literal: true

module DependentsVerification
  ##
  # DependentsVerification 21-0538 Active::Record
  # @see app/model/saved_claim
  #
  class SavedClaim < ::SavedClaim
    # Dependents Verification Form ID
    FORM = DependentsVerification::FORM_ID

    # the predefined regional office address
    #
    # @return [Array<String>] the address lines of the regional office
    def regional_office
      ['Department of Veterans Affairs',
       'Evidence Intake Center',
       'P.O. Box 4444',
       'Janesville, Wisconsin 53547-4444']
    end

    ##
    # Returns the business line associated with this process
    #
    # @return [String]
    def business_line
      'OTH'
    end

    # Utility function to retrieve claimant email from form
    #
    # @return [String] the claimant email
    def email
      if Flipper.enabled?(:lifestage_va_profile_email)
        parsed_form['va_profile_email'] || parsed_form['email']
      else
        parsed_form['email']
      end
    end

    # Utility function to retrieve veteran first name from form
    #
    # @return [String]
    def veteran_first_name
      parsed_form.dig('veteranInformation', 'fullName', 'first')
    end

    # Utility function to retrieve veteran last name from form
    #
    # @return [String]
    def veteran_last_name
      parsed_form.dig('veteranInformation', 'fullName', 'last')
    end
  end
end
