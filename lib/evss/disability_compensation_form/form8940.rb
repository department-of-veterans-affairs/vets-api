# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    class Form8940 < AncillaryFormPopulator
      def translate
        return nil unless @veteran_data && @final_output
        @final_output['veteranAddress'] = address(@veteran_data['mailingAddress'])
        @final_output
      end

      private

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
