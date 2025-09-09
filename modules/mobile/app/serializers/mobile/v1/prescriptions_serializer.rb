# frozen_string_literal: true

module Mobile
  module V1
    class PrescriptionsSerializer < Mobile::V0::PrescriptionsSerializer
      # Inherit all attributes and behavior from v0 for API compatibility
      # Add UHD-specific attributes
      
      attribute :data_source_system
      attribute :prescription_source

      # Override type to maintain consistency
      set_type :Prescription
    end
  end
end