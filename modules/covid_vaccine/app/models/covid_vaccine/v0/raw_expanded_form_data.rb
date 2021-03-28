# frozen_string_literal: true

module CovidVaccine
  module V0
    class RawExpandedFormData
      include ActiveModel::Validations

      ATTRIBUTES = %w[first_name last_name ssn birth_date email vaccine_interest preferred_facility
                      address_line1 city state zip_code].freeze
      ZIP_REGEX = /\A^\d{5}(-\d{4})?$\z/.freeze

      attr_accessor(*ATTRIBUTES)

      validates :first_name, presence: true
      validates :last_name, presence: true
      validates :ssn, format: { with: /\A\d{9}\z/, message: 'should be in the form 123121234' }
      validates :birth_date, format: { with: /\A\d{4}-\d{2}-\d{2}\z/, message: 'should be in the form yyyy-mm-dd' }
      validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
      # validates :vaccine_interest, presence: true
      # TODO: Check whether this is required or not
      # validates :preferred_facility, presence: true
      validates :address_line1, presence: true
      validates :city, presence: true
      validates :state, presence: true
      validates :zip_code, format: { with: ZIP_REGEX, message: 'should be in the form 12345 or 12345-1234' }

      def initialize(attributes = {})
        attributes.each do |name, value|
          send("#{name}=", value) if name.to_s.in?(ATTRIBUTES)
        end
      end
    end
  end
end
