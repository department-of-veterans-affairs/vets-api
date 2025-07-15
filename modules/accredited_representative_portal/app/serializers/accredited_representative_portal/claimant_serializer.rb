# frozen_string_literal: true

module AccreditedRepresentativePortal
  class ClaimantSerializer < ApplicationSerializer
    set_id(&:id)

    attributes :first_name, :last_name, :city, :state, :postal_code

    attribute :representative do |claimant, params|
      active_poa_codes = params[:active_poa_codes] || []
      claimant.representative if active_poa_codes.include?(claimant.claimant_poa_code)
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
