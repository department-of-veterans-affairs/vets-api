# frozen_string_literal: true

require 'active_model'

module SSOe
  module Models
    class User
      include ActiveModel::Validations

      attr_reader :first_name, :last_name, :birth_date, :ssn, :email, :phone

      validates :first_name, :last_name, :birth_date, :ssn, :email, :phone, presence: true

      # rubocop:disable Metrics/ParameterLists
      def initialize(first_name:, last_name:, birth_date:, ssn:, email:, phone:)
        @first_name = first_name
        @last_name = last_name
        @birth_date = birth_date
        @ssn = ssn
        @email = email
        @phone = phone
      end
      # rubocop:enable Metrics/ParameterLists
    end
  end
end
