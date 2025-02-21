# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PowerOfAttorneyRequestSerializer < ApplicationSerializer
    TO_BE_REDACTED = %w[ssn vaFileNumber].freeze

    attributes :claimant_id, :created_at, :expires_at

    attribute :power_of_attorney_form do |poa_request|
      poa_request.power_of_attorney_form.parsed_data.tap do |form|
        PowerOfAttorneyRequest::ClaimantTypes::ALL.product(TO_BE_REDACTED).each do |(claimant_type, key)|
          next unless form[claimant_type].present? && form[claimant_type][key].present?

          form[claimant_type][key] = redact_except_last_four_digits(form[claimant_type][key])
        end

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

    class << self
      def redact_except_last_four_digits(input)
        return '' if input.to_s.strip.empty?

        input = input.to_s
        input.gsub(/.(?=.{4})/, 'X')
      end
    end
  end
end
