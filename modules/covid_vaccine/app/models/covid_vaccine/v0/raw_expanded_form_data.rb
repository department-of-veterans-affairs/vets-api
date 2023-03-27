# frozen_string_literal: true

module CovidVaccine
  module V0
    class RawExpandedFormData
      include ActiveModel::Validations

      ATTRIBUTES = %w[first_name middle_name last_name ssn birth_date birth_sex
                      applicant_type veteran_ssn veteran_birth_date
                      last_branch_of_service character_of_service date_range
                      preferred_facility email_address phone sms_acknowledgement
                      address_line1 address_line2 address_line3 city state_code zip_code country_name
                      compliance_agreement privacy_agreement_accepted].freeze
      ZIP_REGEX = /\A^\d{5}(-\d{4})?$\z/

      attr_accessor(*ATTRIBUTES)

      validates :first_name, presence: true
      validates :last_name, presence: true
      validates :ssn, format: { with: /\A\d{9}\z/, message: 'should be in the form 123121234' }
      validates :birth_date, format: { with: /\A\d{4}-\d{2}-\d{2}\z/, message: 'should be in the form yyyy-mm-dd' }
      validates :veteran_ssn, format: { with: /\A\d{9}\z/,
                                        message: 'should be in the form 123121234' }, allow_blank: true
      validates :veteran_birth_date, format: { with: /\A\d{4}-\d{2}-\d{2}\z/,
                                               message: 'should be in the form yyyy-mm-dd' }, allow_blank: true
      validates :email_address, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
      validates :address_line1, presence: true
      validates :city, presence: true
      validates :state_code, presence: true
      validates :zip_code, format: { with: ZIP_REGEX, message: 'should be in the form 12345 or 12345-1234' },
                           if: :us_address?

      def initialize(attributes = {})
        attributes.each do |name, value|
          send("#{name}=", value) if name.to_s.in?(ATTRIBUTES)
        end
      end

      def us_address?
        country_name == 'USA'
      end
    end
  end
end
