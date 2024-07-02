# frozen_string_literal: true

module CovidVaccine
  module V0
    class RegistrationSubmissionSerializer
      include JSONAPI::Serializer

      set_id do |object|
        object&.sid || ''
      end

      attribute :created_at

      attribute :vaccine_interest do |object|
        object.raw_form_data['vaccine_interest']
      end

      attribute :zip_code do |object|
        object.raw_form_data['zip_code']
      end

      attribute :zip_code_details do |object|
        object.raw_form_data['zip_code_details']
      end

      attribute :phone do |object|
        object.raw_form_data['phone']
      end

      attribute :email do |object|
        object.raw_form_data['email']
      end

      attribute :first_name do |object|
        object.raw_form_data['first_name']
      end

      attribute :last_name do |object|
        object.raw_form_data['last_name']
      end

      attribute :birth_date do |object|
        object.raw_form_data['birth_date']
      end
    end
  end
end
