# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    class Form0781
      def initialize(user, form_content)
        @user = user
        @veteran_data = form_content.dig('form526', 'veteran')
        @final_output = form_content.dig('form526', 'form0781')
      end

      def translate
        return nil unless @veteran_data && @final_output
        @final_output['vaFileNumber'] = @user.ssn
        @final_output['veteranSocialSecurityNumber'] = @user.ssn
        @final_output['veteranServiceNumber'] = @veteran_data['serviceNumber']
        @final_output['veteranFullName'] = full_name
        @final_output['veteranDateOfBirth'] = @user.birth_date
        @final_output['email'] = @veteran_data['emailAddress']
        @final_output['veteranPhone'] = @veteran_data['primaryPhone']
        @final_output['veteranSecondaryPhone'] = '' # No secondary phone available in 526 PreFill
        @final_output.to_json
      end

      private

      def full_name
        {
          "first": @user.first_name,
          "middle": @user.middle_name,
          "last": @user.last_name
        }
      end
    end
  end
end
