# frozen_string_literal: true

module AccreditedRepresentativePortal
  class ClaimantSerializer < ApplicationSerializer
    set_id(&:id)

    attributes :first_name, :last_name, :city, :state, :postal_code, :representative

    attribute :poa_requests do |claimant|
      claimant.poa_requests.map do |poa_request|
        PowerOfAttorneyRequestSerializer.new(poa_request).serializable_hash
      end
    end
  end
end
