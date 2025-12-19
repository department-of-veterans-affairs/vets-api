# frozen_string_literal: true

module Mobile
  module V0
    class TravelPayClaimDetailsSerializer
      include JSONAPI::Serializer

      set_type :travelPayClaimDetails

      attributes :id,
                 :claimNumber,
                 :claimName,
                 :claimantFirstName,
                 :claimantMiddleName,
                 :claimantLastName,
                 :claimStatus,
                 :facilityName,
                 :totalCostRequested,
                 :reimbursementAmount,
                 :rejectionReason,
                 :decisionLetterReason,
                 :appointment,
                 :expenses,
                 :documents,
                 :createdOn,
                 :modifiedOn

      attribute :appointmentDate do |object|
        object.appointmentDate&.chomp('Z')
      end
    end
  end
end
