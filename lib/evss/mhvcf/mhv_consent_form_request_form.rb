# frozen_string_literal: true
require 'active_model'

module EVSS
  module MHVCF
    class MHVConsentFormRequestForm
      extend ActiveModel::Naming
      include ActiveModel::Validations
      include Virtus.model(nullify_blank: true)

      attribute :patient_full_name, String
      attribute :ssn, String
      attribute :ssn_masked, String
      attribute :dob, String
      attribute :patient_phone_number, String
      attribute :date_sign, String

      validates :patient_full_name, presence: true
      validates :ssn,
                presence: true,
                length: { maximum: 9, minimum: 9 }
      validates :dob, :date_sign,
                presence: true,
                format: { with: %r(\d{2}\/\d{2}\/\d{4}), message: 'Date must be in the following format: mm/dd/yyyy' }
      #validates :patient_phone_number, presence: true # additional Validations?

      # The EVSS submit endpoint is designed to be generic, to support multiple different
      # forms. As such, the way params are to be sent is this strange sort of tuple syntax
      # where the value (in the key/value pair) is always provided as an array.
      def params
        {
          form_data: {
            common_headers: [],
            form_config_id: {
              config_version: '1.0.0',
              form_type: '10-5345A-MHV'
            },
            form_field_data: attribute_tuple_set,
            over_flow_form_field_data: []
          }
        }
      end

      private

      def attribute_tuple_set
        attribute_set.map do |attribute|
          {
            name: attribute.name,
            values: Array.wrap(send(attribute.name))
          }
        end
      end
    end
  end
end
