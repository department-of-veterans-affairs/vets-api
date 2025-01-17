# frozen_string_literal: true

module ClaimsApi
  class Process < ApplicationRecord
    belongs_to :processable, polymorphic: true

    VALID_POA_STEP_TYPES = %w[PDF_SUBMISSION POA_UPDATE POA_ACCESS_UPDATE CLAIMANT_NOTIFICATION].freeze
    VALID_POA_STEP_STATUSES = %w[IN_PROGRESS SUCCESS FAILED].freeze

    validates :step_type, presence: true
    validate :validate_step_type_and_status

    def next_step
      case processable_type
      when 'ClaimsApi::PowerOfAttorney'
        step_map = {
          'PDF_SUBMISSION' => 'POA_UPDATE',
          'POA_UPDATE' => 'POA_ACCESS_UPDATE',
          'POA_ACCESS_UPDATE' => 'CLAIMANT_NOTIFICATION'
        }
        step_map[step_type]
      end
    end

    private

    def validate_step_type_and_status
      case processable_type
      when 'ClaimsApi::PowerOfAttorney'
        validate_power_of_attorney_enums
      else
        errors.add(:processable_type, 'is not recognized')
      end
    end

    def validate_power_of_attorney_enums
      errors.add(:step_type, 'is not recognized') unless VALID_POA_STEP_TYPES.include?(step_type)
      unless step_status.nil? || VALID_POA_STEP_STATUSES.include?(step_status)
        errors.add(:step_status, 'is not recognized')
      end
    end
  end
end
