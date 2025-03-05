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
    validates :power_of_attorney_holder_type, inclusion: { in: PowerOfAttorneyHolder::Types::ALL }

    accepts_nested_attributes_for :power_of_attorney_form

    def expires_at
      created_at + EXPIRY_DURATION if unresolved?
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
    scope :not_expired, lambda {
      where.not(resolution: { resolving_type: 'AccreditedRepresentativePortal::PowerOfAttorneyRequestExpiration' })
    }

    scope :for_user, lambda { |user|
      for_power_of_attorney_holders(
        user.activated_power_of_attorney_holders
      )
    }

    scope :for_power_of_attorney_holders, lambda { |poa_holders|
      return none if poa_holders.empty?

      prefix = 'power_of_attorney_holder'
      names = PowerOfAttorneyHolder::PRIMARY_KEY_ATTRIBUTE_NAMES
      prefixed_names = names.map { |name| :"#{prefix}_#{name}" }
      values = poa_holders.map { |poa_holder| poa_holder.to_h.values_at(*names) }

      where(prefixed_names => values)
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
