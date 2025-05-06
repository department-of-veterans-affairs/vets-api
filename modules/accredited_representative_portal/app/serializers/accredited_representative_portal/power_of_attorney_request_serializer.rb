# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PowerOfAttorneyRequestSerializer < ApplicationSerializer
    REDACTION_POLICY = {
      FIELDS: %w[ssn vaFileNumber].freeze,
      CHARS_VISIBLE: 4
    }.freeze

    attributes :claimant_id, :created_at, :expires_at

    attribute :power_of_attorney_form do |poa_request|
      poa_request.power_of_attorney_form.parsed_data.tap do |form|
        PowerOfAttorneyRequest::ClaimantTypes::ALL.product(REDACTION_POLICY[:FIELDS]).each do |(claimant_type, key)|
          value = form.dig(claimant_type, key).to_s
          next if value.blank?

          redacted_value = value[-REDACTION_POLICY[:CHARS_VISIBLE]..]
          form[claimant_type][key] = redacted_value
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
      status =
        case poa_request.power_of_attorney_form_submission&.status
        when PowerOfAttorneyFormSubmission::Statuses::SUCCEEDED
          'SUCCEEDED'
        when PowerOfAttorneyFormSubmission::Statuses::ENQUEUE_FAILED,
          PowerOfAttorneyFormSubmission::Statuses::FAILED
          'FAILED'
        else
          'PENDING'
        end

      { status: }
    end
  end
end
