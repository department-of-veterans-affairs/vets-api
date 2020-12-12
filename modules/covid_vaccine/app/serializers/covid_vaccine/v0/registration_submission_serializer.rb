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
      
      # TODO: Make robust to selecting from raw_form_data or form_data
      # in case GET is called before submission
      %i[vaccine_interest zip_code phone email first_name last_name].each do |attr|
        define_method attr do
          object.form_data[attr]
        end
      end

      def zip_code_details
        object.form_data[:time_at_zip]
      end

      def birth_date
        object.form_data[:date_of_birth]
      end
    end
  end
end
