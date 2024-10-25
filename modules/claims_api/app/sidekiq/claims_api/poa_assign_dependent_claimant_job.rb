# frozen_string_literal: true

module ClaimsApi
  class PoaAssignDependentClaimantJob < ClaimsApi::ServiceBase
    def perform(dependent_claimant_poa_assignment_service)
      byebug
      dependent_claimant_poa_assignment_service.assign_poa_to_dependent!
    end
  end
end
