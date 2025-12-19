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
