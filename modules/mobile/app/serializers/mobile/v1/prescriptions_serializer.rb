# frozen_string_literal: true

module Mobile
  module V1
    class PrescriptionsSerializer < Mobile::V0::PrescriptionsSerializer
      # Inherit all attributes and behavior from v0 for API compatibility
      # Add UHD-specific attributes
      
      attribute :data_source_system
      attribute :prescription_source
      attribute :tracking_info

      # Backward compatibility: provide first tracking info as top-level attributes
      attribute :tracking_number do |object|
        object.tracking_info&.first&.dig(:tracking_number) || object.tracking_info&.first&.dig('tracking_number')
      end

      attribute :shipper do |object|
        object.tracking_info&.first&.dig(:shipper) || object.tracking_info&.first&.dig('shipper')
      end

      # Override type to maintain consistency
      set_type :Prescription
    end
  end
end