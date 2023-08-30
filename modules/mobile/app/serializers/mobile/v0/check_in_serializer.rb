# frozen_string_literal: true

module Mobile
  module V0
    class CheckInSerializer
      include JSONAPI::Serializer

      set_type :check_in
      attributes :id, :code, :message

      def initialize(user_id, attributes)
        @attributes = attributes

        resource = CheckInStruct.new(id: user_id,
                                     code:,
                                     message:)
        super(resource)
      end

      def code
        case @attributes['message']
        when 'success with appointmentIen: test-appt-ien, patientDfn: test-patient-ien, stationNo: test-station-no'
          'check-in-success'
        end
      end

      def message
        case @attributes['message']
        when 'success with appointmentIen: test-appt-ien, patientDfn: test-patient-ien, stationNo: test-station-no'
          'Check-In successful'
        end
      end

      CheckInStruct = Struct.new(:id, :code, :message)
    end
  end
end
