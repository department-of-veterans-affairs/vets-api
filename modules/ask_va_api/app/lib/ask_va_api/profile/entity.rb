# frozen_string_literal: true

module AskVAApi
  module Profile
    class Entity
      ATTRIBUTES = %i[
        first_name middle_name last_name preferred_name suffix
        gender pronouns country street city state zip_code
        province business_phone personal_phone personal_email
        business_email school_state school_facility_code service_number
        claim_number veteran_service_start_date veteran_service_end_date
        date_of_birth edipi
      ].freeze

      attr_reader :id
      attr_accessor(*ATTRIBUTES)

      def initialize(data)
        @id = data[:icn]

        ATTRIBUTES.each do |attribute|
          camel_case_key = attribute.to_s.split('_').collect(&:capitalize).join
          send("#{attribute}=", data[camel_case_key.to_sym] || data[attribute.to_s.camelcase(:lower).to_sym])
        end
      end
    end
  end
end
