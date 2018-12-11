# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    class Form8940
      def initialize(user, form_content)
        @user = user
        @veteran_data = form_content.dig('form526', 'veteran')
        @final_output = form_content.dig('form526', 'form8940')
      end

      def translate
        return nil unless @veteran_data && @final_output
        @final_output['vaFileNumber'] = @user.ssn
        @final_output['veteranSocialSecurityNumber'] = @user.ssn
        @final_output['veteranFullName'] = full_name
        @final_output['veteranDateOfBirth'] = @user.birth_date
        @final_output['veteranAddress'] = address(@veteran_data['mailingAddress'])
        @final_output['email'] = @veteran_data['emailAddress']
        @final_output['veteranPhone'] = @veteran_data['primaryPhone']
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

      def address(data)
        {
          "city": data['city'],
          "country": data['country'],
          "postalCode": data['zipCode'],
          "street": data['addressLine1'],
          "street2": data['addressLine2'],
          "state": data['state']
        }
      end
    end
  end
end
