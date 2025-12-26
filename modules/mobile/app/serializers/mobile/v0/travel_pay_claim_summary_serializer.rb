# frozen_string_literal: true

module Mobile
  module V0
    class TravelPayClaimSummarySerializer
      include JSONAPI::Serializer

      set_type :travelPayClaimSummary

      attributes :id,
                 :claimNumber,
                 :claimStatus,
                 :facilityId,
                 :facilityName,
                 :totalCostRequested,
                 :reimbursementAmount,
                 :createdOn,
                 :modifiedOn

      # BTSSS incorrectly labels local appointment times with 'Z' (UTC) suffix.
      # Strip 'Z' to prevent timezone confusion in travel pay claims list & details pages in mobile app.
      attribute :appointmentDateTime do |object|
        object.appointmentDateTime&.chomp('Z')
      end
    end
  end
end
