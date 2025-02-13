# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PowerOfAttorneyRequest < ApplicationRecord
    module ClaimantTypes
      ALL = [
        DEPENDENT = 'dependent',
        VETERAN = 'veteran'
      ].freeze
    end

    EXPIRY_DURATION = 60.days

    belongs_to :claimant, class_name: 'UserAccount'

    has_one :power_of_attorney_form,
            inverse_of: :power_of_attorney_request,
            required: true

    has_many :power_of_attorney_form_submissions
    has_one :power_of_attorney_form_submission

    has_one :resolution,
            class_name: 'PowerOfAttorneyRequestResolution',
            inverse_of: :power_of_attorney_request

    belongs_to :accredited_organization, class_name: 'Veteran::Service::Organization',
                                         foreign_key: :power_of_attorney_holder_poa_code,
                                         primary_key: :poa,
                                         optional: true
    belongs_to :accredited_individual, class_name: 'Veteran::Service::Representative',
                                       foreign_key: :accredited_individual_registration_number,
                                       primary_key: :representative_id,
                                       optional: true

    before_validation :set_claimant_type

    validates :claimant_type, inclusion: { in: ClaimantTypes::ALL }

    def success_form_submission
      power_of_attorney_form_submissions.succeeded.take
    end

    def expires_at
      created_at + EXPIRY_DURATION if pending?
    end

    def pending?
      !resolved? || !success_form_submission
    end

    def processed?
      declined? || expired? || success_form_submission
    end

    def unresolved?
      !resolved?
    end

    def resolved?
      resolution.present?
    end

    def accepted?
      resolved? && resolution.resolving.is_a?(PowerOfAttorneyRequestDecision) &&
        resolution.resolving.type == PowerOfAttorneyRequestDecision::Types::ACCEPTANCE
    end

    def declined?
      resolved? && resolution.resolving.is_a?(PowerOfAttorneyRequestDecision) &&
        resolution.resolving.type == PowerOfAttorneyRequestDecision::Types::DECLINATION
    end

    def expired?
      resolved? && resolution.resolving.is_a?(PowerOfAttorneyRequestExpiration)
    end

    scope :unresolved, -> { where.missing(:resolution) }
    scope :resolved, -> { joins(:resolution) }
    scope :pending, lambda {
      left_joins(:power_of_attorney_form_submissions).unresolved.or(
        where("ar_power_of_attorney_form_submissions.status != 'succeeded'")
      )
    }
    scope :processed, lambda {
      left_joins(:power_of_attorney_form_submissions).resolved.where(
        'ar_power_of_attorney_form_submissions.status IS NULL OR ' \
        "ar_power_of_attorney_form_submissions.status = 'succeeded'"
      )
    }
    scope :not_expired, lambda {
      where.not(resolution: { resolving_type: 'AccreditedRepresentativePortal::PowerOfAttorneyRequestExpiration' })
    }

    private

    def set_claimant_type
      self.claimant_type =
        if power_of_attorney_form.parsed_data['dependent']
          ClaimantTypes::DEPENDENT
        elsif power_of_attorney_form.parsed_data['veteran']
          ClaimantTypes::VETERAN
        end
    end
  end
end
