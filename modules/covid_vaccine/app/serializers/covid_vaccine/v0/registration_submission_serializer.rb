# frozen_string_literal: true

module CovidVaccine
  module V0
    class RegistrationSubmissionSerializer < ActiveModel::Serializer
      attribute :created_at
      attribute :vaccine_interest
      attribute :zip_code
      attribute :zip_code_details
      attribute :phone
      attribute :email
      attribute :first_name
      attribute :last_name
      attribute :birth_date

      def id
        object.sid
      end

      %i[vaccine_interest zip_code zip_code_details phone email first_name last_name birth_date].each do |attr|
        define_method attr do
          object.raw_form_data[attr.to_s]
        end
      end
    end
  end
end
