# frozen_string_literal: true

module Mobile
  module V0
    class PrescriptionTrackingSerializer
      include FastJsonapi::ObjectSerializer

      set_type :PrescriptionTracking
      set_id(&:prescription_id)

      attributes :prescription_name,
                 :tracking_number,
                 :shipped_date,
                 :delivery_service

      attribute :other_prescriptions do |object|
        object.other_prescriptions.map do |other|
          {
            prescription_name: other[:prescription_name],
            prescription_number: other[:prescription_number]
          }
        end
      end
    end
  end
end
