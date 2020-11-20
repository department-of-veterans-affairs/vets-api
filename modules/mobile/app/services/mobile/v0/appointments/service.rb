# frozen_string_literal: true

module Mobile
  module V0
    module Appointments
      class Service < VAOS::SessionService
        def get_appointments(start_date, end_date, use_cache = true)
          params = {
            startDate: start_date.utc.iso8601,
            endDate: end_date.utc.iso8601,
            pageSize: 0,
            useCache: use_cache
          }

          responses = { cc: nil, va: nil }
          errors = { cc: nil, va: nil }

          config.parallel_connection.in_parallel do
            responses[:cc], errors[:cc] = get(cc_url, params)
            responses[:va], errors[:va] = get(va_url, params)
          end

          if errors.values.any? { |e| !e.nil? }
            Rails.logger.error('mobile get va appointments call failed') if errors[:va]
            Rails.logger.error('mobile get community care appointments call failed') if errors[:cc]
            raise Common::Exceptions::BackendServiceException, 'VAOS_502'
          end

          responses
        end

        private

        def get(url, params)
          response = config.parallel_connection.get(url, params, headers)
          [response, nil]
        rescue => e
          [nil, e]
        end

        def config
          Mobile::V0::Appointments::Configuration.instance
        end

        def responses_ok?(responses)
          responses[:cc]&.status == 200 && responses[:va]&.status == 200
        end

        def va_url
          "/appointments/v1/patients/#{@user.icn}/appointments"
        end

        def cc_url
          '/var/VeteranAppointmentRequestService/v4/rest/direct-scheduling' \
            "/patient/ICN/#{@user.icn}/booked-cc-appointments"
        end
      end
    end
  end
end
