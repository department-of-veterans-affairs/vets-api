# frozen_string_literal: true

module VAOS
  module V2
    class AppointmentsSerializer
      include FastJsonapi::ObjectSerializer

      set_id :id

      set_type :appointments

      attributes :id,
                 :kind,
                 :status,
                 :serviceType,
                 :patientIcn,
                 :clinic,
                 :telehealth,
                 :practitioners,
                 :reason,
                 :start,
                 :end,
                 :minutesDuration,
                 :slot,
                 :requestedPeriods,
                 :contact,
                 :preferredTiomeForPhoneCall,
                 :priority,
                 :cancellationReason,
                 :description,
                 :comment
    end
  end
end
