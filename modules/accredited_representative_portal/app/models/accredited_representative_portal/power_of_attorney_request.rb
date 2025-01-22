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

    belongs_to :power_of_attorney_holder,
               inverse_of: :power_of_attorney_requests,
               polymorphic: true

    belongs_to :organization, class_name: 'Veteran::Service::Organization', foreign_key: :ogc_poa_code, primary_key: :poa

    default_scope { includes(:organization) }
    
    before_validation :set_claimant_type

    validates :claimant_type, inclusion: { in: ClaimantTypes::ALL }

    def expires_at
      created_at + EXPIRY_DURATION if unresolved?
    end

    def unresolved?
      !resolved?
    end

    def resolved?
      resolution.present?
    end

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
