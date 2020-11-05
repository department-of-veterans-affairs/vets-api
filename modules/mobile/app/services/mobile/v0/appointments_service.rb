# frozen_string_literal: true

module Mobile
  module V0
    class AppointmentsService < VAOS::SessionService
      
      def get_appointments(start_date, end_date, use_cache = true)
        params = {
          startDate: start_date.utc.iso8601,
          endDate: end_date.utc.iso8601,
          pageSize: 0,
          useCache: use_cache
        }
        
        responses = {}
        
        config.connection.in_parallel do
          responses[:cc] = connection.get(cc_url, params, headers)
          responses[:va] = connection.get(va_url, params, headers)
          
          raise "foop" unless responses_ok?(responses)
        end
        
        responses
      end
      
      private
      
      def responses_ok?(response)
         response[:cc].status == 200 && response[:va].status == 200
      end
      
      def va_url
        "/appointments/v1/patients/#{@user.icn}/appointments"
      end
      
      def cc_url
        "/var/VeteranAppointmentRequestService/v4/rest/direct-scheduling/patient/ICN/#{@user.icn}/booked-cc-appointments"
      end
      
      def service
        @service ||= VAOS::AppointmentService.new(@user)
      end
    end
  end
end
