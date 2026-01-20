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
                 :expenses,
                 :documents,
                 :createdOn,
                 :modifiedOn

      # BTSSS incorrectly labels local appointment times with 'Z' (UTC) suffix
      # Fix to remove 'Z' to prevent timezone confusion in travel pay claims list & details pages in mobile app
      # We may move this fix to the mobile FE in the future
      attribute :appointmentDate do |object|
        object.appointmentDate&.chomp('Z')
      end

      attribute :appointment do |object|
        appt = object.appointment
        if appt && appt['appointmentDateTime']
          appt.merge('appointmentDateTime' => appt['appointmentDateTime']&.chomp('Z'))
        else
          appt
        end
      end
    end
  end
end
