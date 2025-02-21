# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PowerOfAttorneyRequestSerializer < ApplicationSerializer
    attributes :claimant_id, :created_at, :expires_at

    attribute :power_of_attorney_form do |poa_request|
      poa_request.power_of_attorney_form.parsed_data.tap do |form|
        case poa_request.claimant_type
        when PowerOfAttorneyRequest::ClaimantTypes::DEPENDENT
          form['claimant'] = form.delete('dependent')
        when PowerOfAttorneyRequest::ClaimantTypes::VETERAN
          form['claimant'] = form.delete('veteran')
          form.delete('dependent')
        end
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

    attribute :accredited_individual do |poa_request|
      AccreditedIndividualSerializer
        .new(poa_request.accredited_individual)
        .serializable_hash
    end

    attribute :power_of_attorney_holder,
              if: ->(poa_request) { poa_request.accredited_organization.present? } do |poa_request|
      OrganizationPowerOfAttorneyHolderSerializer
        .new(poa_request.accredited_organization)
        .serializable_hash
    end

    attribute :power_of_attorney_form_submission,
              if: ->(poa_request) { poa_request.accepted? } do |poa_request|
      time = poa_request.created_at.to_i
      status =
        case time % 3
        when 0 then 'PENDING'
        when 1 then 'FAILED'
        when 2 then 'SUCCEEDED'
        end

      { status: }
    end
  end
end
