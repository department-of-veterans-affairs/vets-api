# frozen_string_literal: true

module Mobile
  module V0
    class TravelPayClaimSummarySerializer
      include JSONAPI::Serializer

      set_type :travelPayClaimSummary

      attributes :id,
                 :claimNumber,
                 :claimStatus,
                 :appointmentDateTime,
                 :facilityId,
                 :facilityName,
                 :totalCostRequested,
                 :reimbursementAmount,
                 :createdOn,
                 :modifiedOn
    end
  end
end
