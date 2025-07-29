# frozen_string_literal: true

module AccreditedRepresentativePortal
  class ClaimantSerializer < ApplicationSerializer
    MILITARY_STATE_CODES = %w[AE AP AA].freeze

    set_id(&:id)

    attributes :first_name, :last_name, :state, :postal_code, :representative

    attribute :city do |claimant|
      if MILITARY_STATE_CODES.include? claimant&.state&.upcase
        claimant.city
      else
        claimant.city&.titleize
      end
    end

    attribute :poa_requests do |claimant|
      pending_poa_requests = claimant.poa_requests.unresolved.order(created_at: :desc)
      resolved_poa_requests = claimant.poa_requests.resolved.order(created_at: :desc)
      [*pending_poa_requests, *resolved_poa_requests].map do |poa_request|
        PowerOfAttorneyRequestSerializer.new(poa_request).serializable_hash
      end
    end
  end
end
