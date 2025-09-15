# frozen_string_literal: true

module AccreditedRepresentativePortal
  class ClaimantSerializer < ApplicationSerializer
    MILITARY_STATE_CODES = %w[AE AP AA].freeze

    set_id do |object|
      object[:claimant_representative].claimant_id
    end

    attribute :first_name do |object|
      object[:claimant_profile].given_names.first
    end

    attribute :last_name do |object|
      object[:claimant_profile].family_name
    end

    attribute :state do |object|
      object[:claimant_profile].address&.state
    end

    attribute :postal_code do |object|
      object[:claimant_profile].address&.postal_code
    end

    attribute :representative do |object|
      object[:claimant_representative].power_of_attorney_holder.name
    end

    attribute :city do |object|
      address = object[:claimant_profile].address

      if MILITARY_STATE_CODES.include? address&.state&.upcase
        address&.city
      else
        address&.city&.titleize
      end
    end

    attribute :poa_requests do |object|
      poa_requests = object[:power_of_attorney_requests]
      pending_poa_requests = poa_requests.unresolved.order(created_at: :desc)
      resolved_poa_requests = poa_requests.resolved.order(created_at: :desc)
      [*pending_poa_requests, *resolved_poa_requests].map do |poa_request|
        PowerOfAttorneyRequestSerializer.new(poa_request).serializable_hash
      end
    end
  end
end
