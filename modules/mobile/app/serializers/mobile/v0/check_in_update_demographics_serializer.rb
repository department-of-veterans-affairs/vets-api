# frozen_string_literal: true

module Mobile
  module V0
    class CheckInUpdateDemographicsSerializer
      include JSONAPI::Serializer

      set_type :demographicConfirmations
      attributes :contact_needs_update, :emergency_contact_needs_update, :next_of_kin_needs_update

      def initialize(demographics_updates)
        resource = DemographicConfirmationsStruct.new(
          id: demographics_updates[:id],
          contact_needs_update: demographics_updates[:demographicsNeedsUpdate],
          emergency_contact_needs_update: demographics_updates[:emergencyContactNeedsUpdate],
          next_of_kin_needs_update: demographics_updates[:nextOfKinNeedsUpdate]
        )

        super(resource)
      end
    end

    DemographicConfirmationsStruct = Struct.new(:id, :contact_needs_update, :emergency_contact_needs_update,
                                                :next_of_kin_needs_update)
  end
end
