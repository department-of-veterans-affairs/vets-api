# frozen_string_literal: true

module CovidVaccine
  module V0
    class RegistrationSummarySerializer
      include JSONAPI::Serializer

      set_id { '' }

      attribute :created_at

      attribute :vaccine_interest do |object|
        object.raw_form_data['vaccine_interest']
      end

      attribute :zip_code do |object|
        object.raw_form_data['zip_code']
      end
    end
  end
end
