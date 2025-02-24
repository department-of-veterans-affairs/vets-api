# frozen_string_literal: true

module DebtsApi
  class V0::DigitalDispute < Common::Base
    include ActiveModel::Validations
    STATS_KEY = 'api.digital_dispute_submission'

    attribute :veteran_information, Hash
    attribute :selected_debts, Array
    attribute :user_icn, String

    validate :validate_veteran_information
    validate :validate_selected_debts

    def initialize(attributes, user)
      super()
      self.user_icn = user.icn
      self.attributes = attributes.to_h.merge(user_icn: user.icn)
    end

    def sanitized_json
      as_json(except: [:user_icn])
    end

    private

    def validate_veteran_information
      required_keys = %w[email mobile_phone mailing_address]
      missing_keys = required_keys - veteran_information.keys
      unless missing_keys.empty?
        errors.add(:veteran_information, "is missing required information: #{missing_keys.join(', ')}")
      end

      if veteran_information['email'].present? && veteran_information['email'] !~ URI::MailTo::EMAIL_REGEXP
        errors.add(:veteran_information, 'must include a valid email address')
      end
    end

    def validate_selected_debts
      selected_debts.each_with_index do |debt, index|
        required_keys = %w[debt_type dispute_reason support_statement]

        required_keys.each do |key|
          errors.add(:selected_debts, "entry ##{index + 1}: #{key} cannot be blank") if debt[key].blank?
        end
      end
    end
  end
end
