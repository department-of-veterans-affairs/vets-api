# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PowerOfAttorneyRequestSerializer < ApplicationSerializer
    attributes :claimant_id, :created_at, :expires_at

    attribute :power_of_attorney_form do |poa_request|
      poa_request.power_of_attorney_form.parsed_data.tap do |form|
        claimant_key =
          case poa_request.claimant_type
          when PowerOfAttorneyRequest::ClaimantTypes::DEPENDENT
            'dependent'
          when PowerOfAttorneyRequest::ClaimantTypes::VETERAN
            'veteran'
          end

        form['claimant'] = form.delete(claimant_key)
        form.delete('dependent')
      end
    end

    attribute :resolution do |poa_request|
      next unless poa_request.resolution

      serializer =
        case poa_request.resolution.resolving
        when PowerOfAttorneyRequestDecision
          DecisionSerializer
        when PowerOfAttorneyRequestExpiration
          ExpirationSerializer
        end

      serializer
        .new(poa_request.resolution)
        .serializable_hash
    end

    attribute :power_of_attorney_holder do |poa_request|
      serializer =
        case poa_request.power_of_attorney_holder
        when AccreditedOrganization
          OrganizationPowerOfAttorneyHolderSerializer
        end

      serializer
        .new(poa_request.power_of_attorney_holder)
        .serializable_hash
        .tap { |hash| hash.delete(:id) }
    end
  end
end
