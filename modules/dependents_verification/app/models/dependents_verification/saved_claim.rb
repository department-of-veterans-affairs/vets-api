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
      ['Department of Veteran Affairs',
       'Example Address',
       'P.O. Box 0000',
       'Janesville, Wisconsin 53547-5365'] # TODO: update this when we have real address
    end

    ##
    # Returns the business line associated with this process
    #
    # @return [String]
    def business_line
      'TEST' # TODO: update this when we know the business line
    end

    # Utility function to retrieve claimant email from form
    #
    # @return [String] the claimant email
    def email
      parsed_form['email'] || 'test@example.com' # TODO: update this when we have a real email field
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
