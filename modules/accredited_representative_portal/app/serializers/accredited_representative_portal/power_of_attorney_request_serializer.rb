# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PowerOfAttorneyRequestSerializer < ApplicationSerializer
    attributes :claimant_id

    attribute :created_at do |poa_request|
      poa_request.created_at.utc.strftime('%Y-%m-%dT%H:%M:%SZ')
    end

    attribute :expires_at do |poa_request|
      poa_request.resolution.present? ? nil : poa_request.created_at + 60.days
    end

    attribute :power_of_attorney_form do |poa_request|
      if poa_request.power_of_attorney_form.parsed_data['dependent'].present?
        poa_request.power_of_attorney_form.parsed_data.transform_keys { |key| key == 'dependent' ? 'claimant' : key }
      elsif poa_request.power_of_attorney_form.parsed_data['veteran'].present?
        poa_request.power_of_attorney_form.parsed_data
                   .transform_keys { |key| key == 'veteran' ? 'claimant' : key }
                   .tap { |data| data.delete('dependent') }
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
        .serializable_hash.merge(created_at: poa_request.resolution.created_at.utc.strftime('%Y-%m-%dT%H:%M:%SZ'))
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
