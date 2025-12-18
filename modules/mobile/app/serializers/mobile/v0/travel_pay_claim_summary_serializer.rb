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

      attribute :appointmentDateTime do |object|
        object.appointmentDateTime&.chomp('Z')
      end
    end
  end
end
