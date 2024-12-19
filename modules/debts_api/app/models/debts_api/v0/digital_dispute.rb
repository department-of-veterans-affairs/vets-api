# frozen_string_literal: true

module DebtsApi
  class V0::DigitalDispute < Common::Base
    include ActiveModel::Validations
    STATS_KEY = 'api.digital_dispute_submission'

    attribute :contact_information, Hash
    attribute :debt_information, Array
    attribute :user_icn, String

    validate :validate_contact_information
    validate :validate_debt_information

    def initialize(attributes, user)
      super()
      self.user_icn = user.icn
      self.attributes = attributes.to_h.merge(user_icn: user.icn)
    end

    def sanitized_json
      as_json(except: [:user_icn])
    end

    private

    def validate_contact_information
      required_keys = %w[email phone_number address_line1 city]
      missing_keys = required_keys - contact_information.keys
      unless missing_keys.empty?
        errors.add(:contact_information, "is missing required information: #{missing_keys.join(', ')}")
      end

      if contact_information['email'].present? && contact_information['email'] !~ URI::MailTo::EMAIL_REGEXP
        errors.add(:contact_information, 'must include a valid email address')
      end
    end

    def validate_debt_information
      debt_information.each_with_index do |debt, index|
        required_keys = %w[debt dispute_reason support_statement]

        required_keys.each do |key|
          errors.add(:debt_information, "entry ##{index + 1}: #{key} cannot be blank") if debt[key].blank?
        end
      end
    end
  end
end
