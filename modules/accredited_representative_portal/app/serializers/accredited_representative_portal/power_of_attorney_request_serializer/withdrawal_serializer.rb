# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PowerOfAttorneyRequestSerializer
    class WithdrawalSerializer < ResolutionSerializer
      attribute(:type) { 'withdrawal' }

      attribute :request_submitted_on do |resolution|
        resolution.power_of_attorney_request.created_at
      end

      attribute :superseding_request_id do |resolution|
        resolution.resolving.superseding_power_of_attorney_request_id
      end
    end
  end
end
