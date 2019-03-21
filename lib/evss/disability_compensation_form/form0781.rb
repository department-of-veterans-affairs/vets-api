# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    # Transforms a client 0781 form submission into the format expected by the EVSS service
    #
    # @param user [User] The current user
    # @param form_content [Hash] Hash of the parsed JSON submitted by the client
    #
    class Form0781
      def initialize(user, form_content)
        @user = user
        @phone_email = form_content.dig('form526', 'phoneAndEmail')
        @final_output = form_content.dig('form526', 'form0781')
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
        @final_output['email'] = @phone_email['emailAddress']
        @final_output['veteranPhone'] = @phone_email['primaryPhone']
        @final_output['veteranSecondaryPhone'] = '' # No secondary phone available in 526 PreFill
        @final_output['veteranServiceNumber'] = '' # No veteran service number available in 526 PreFill

        # The pdf creation functionality is looking for a single street address
        # instead of a hash
        @final_output['incidents'].each do |incident|
          incident['incidentLocation'] = join_location(incident['incidentLocation']) if incident['incidentLocation']
        end

        @final_output
      end

      private

      def join_location(location)
        [
          location['city'],
          location['state'],
          location['country'],
          location['additionalDetails']
        ].reject(&:blank?).join(', ')
      end

      def full_name
        {
          'first' => @user.first_name,
          'middle' => @user.middle_name,
          'last' => @user.last_name
        }
      end
    end
  end
end
