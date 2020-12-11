# frozen_string_literal: true

module CovidVaccine
  module V0
    class RegistrationSummarySerializer < ActiveModel::Serializer
      attribute :created_at
      attribute :vaccine_interest
      attribute :zip_code

      def id
        object.sid
      end

      %i[vaccine_interest zip_code].each do |attr|
        define_method attr do
          object.form_data[attr]
        end
      end
    end
  end
end
