# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    # Transforms a client 4142 form submission into the format expected by the EVSS service
    # 4142 - AUTHORIZATION TO DISCLOSE INFORMATION TO THE DEPARTMENT OF VETERANS AFFAIRS
    #
    # @param user [User] The current user
    # @param form_content [Hash] Hash of the parsed JSON submitted by the client
    #
    class Form4142
      def initialize(user, form_content)
        @user = user
        @phone_email = form_content.dig('form526', 'phoneAndEmail')
        @mailing_address = form_content.dig('form526', 'mailingAddress')
        @final_output = form_content.dig('form526', 'form4142')
      end

      # Merges the user data and performs the translation
      #
      # @return [Hash] The translated form ready for submission
      #
      def translate
        return nil unless @final_output

        @final_output['vaFileNumber'] = @user.ssn
        @final_output['veteranSocialSecurityNumber'] = @user.ssn
        @final_output['veteranFullName'] = full_name
        @final_output['veteranDateOfBirth'] = @user.birth_date
        @final_output['veteranAddress'] = address(@mailing_address)
        @final_output['email'] = @phone_email['emailAddress']
        @final_output['veteranPhone'] = @phone_email['primaryPhone']
        @final_output['veteranServiceNumber'] = '' # No veteran service number available in 526 PreFill
        @final_output
      end

      private

      def full_name
        {
          'first' => @user.first_name,
          'middle' => @user.middle_name,
          'last' => @user.last_name
        }
      end

      def address(data)
        {
          'city' => data['city'],
          'country' => data['country'],
          'postalCode' => data['zipCode'],
          'street' => data['addressLine1'],
          'street2' => data['addressLine2'],
          'state' => data['state']
        }
      end
    end
  end
end
