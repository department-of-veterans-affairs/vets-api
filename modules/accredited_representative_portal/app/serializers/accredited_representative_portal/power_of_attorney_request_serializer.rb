# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PowerOfAttorneyRequestSerializer < ApplicationSerializer
    attributes :claimant_id, :claimant_type, :created_at

    attribute :power_of_attorney_form do |poa_request|
      poa_request.power_of_attorney_form.parsed_data
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
      PowerOfAttorneyHolderSerializer
        .new(poa_request.power_of_attorney_holder)
        .serializable_hash
    end

    attribute :accredited_individual do |poa_request|
      AccreditedIndividualSerializer
        .new(poa_request.accredited_individual)
        .serializable_hash
    end
  end
end
