# frozen_string_literal: true

module Mobile
  module V1
    class PrescriptionsSerializer < Mobile::V0::PrescriptionsSerializer
      # Inherit all attributes and behavior from v0 for API compatibility
      # Add UHD-specific attributes

      attribute :data_source_system
      attribute :prescription_source
      attribute :tracking_info
      attribute :ndc_number
      attribute :prescribed_date

      # Backward compatibility: provide first tracking info as top-level attributes
      attribute :tracking_number, &:tracking_number

      attribute :shipper, &:shipper

      # Override type to maintain consistency
      set_type :Prescription
    end
  end
end
