# frozen_string_literal: true

module Mobile
  module V0
    class TravelPayClaimSummarySerializer
      include JSONAPI::Serializer

      # set_type :travel_pay_claim_summary

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

      # def initialize(claim_summary)
      #   serialize_claim(claim_summary)
      # end

      # private

      # def serialize_claim(claim_summary)
      #   TravelPayClaimSummary.new(id: claim_summary[:id],
      #                             claimNumber: claim_summary[:claimNumber],
      #                             claimStatus: claim_summary[:claimStatus],
      #                             facilityId: claim_summary[:facilityId],
      #                             facilityName: claim_summary[:facilityName],
      #                             totalCostRequested: claim_summary[:totalCostRequested],
      #                             reimbursementAmount: claim_summary[:reimbursementAmount] || nil,
      #                             appointmentDateTime: claim_summary[:appointmentDateTime],
      #                             createdOn: claim_summary[:createdOn] || DateTime.now,
      #                             modifiedOn: claim_summary[:modifiedOn] || DateTime.now)
      # end
    end
  end
end
