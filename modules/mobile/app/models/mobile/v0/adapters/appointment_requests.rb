# frozen_string_literal: true

require 'sentry_logging'

module Mobile
  module V0
    module Adapters
      class AppointmentRequests
        # accepts an array of appointment requests
        # returns a list of appointments, filtering out any that are not SUBMITTED or CANCELLED
        def parse(requests)
          va_appointments = []
          cc_appointments = []

          requests.each do |request|
            status = status(request)
            next unless status.in?(%w[CANCELLED SUBMITTED])

            if request.cc_appointment_request
              cc_appointments << build_appointment_model(request, CC)
            else
              va_appointments << build_appointment_model(request, VA)
            end
          end

          [va_appointments, cc_appointments]
        end

        private

        # rubocop:disable Metrics/MethodLength
        def build_appointment_model(request, klass)
          start_date = localized_start_date(request)

          Mobile::V0::Appointment.new(
            id: request[:appointment_request_id],
            appointment_type: appointment_type(request, klass),
            cancel_id: nil,
            comment: nil,
            facility_id: klass.facility_id(request),
            sta6aid: nil,
            healthcare_provider: klass.provider_name(request),
            healthcare_service: klass.practice_name(request),
            location: klass.location(request),
            minutes_duration: nil,
            phone_only: phone_only?(request),
            start_date_local: start_date,
            start_date_utc: start_date.utc,
            status: status(request),
            status_detail: status_detail(request),
            time_zone: time_zone(request),
            vetext_id: nil,
            reason: request[:purpose_of_visit],
            is_covid_vaccine: nil,
            is_pending: true,
            proposed_times: proposed_times(request),
            type_of_care: request[:appointment_type],
            patient_phone_number: request[:phone_number],
            patient_email: request[:email],
            best_time_to_call: request[:best_timeto_call],
            friendly_location_name: request[:friendly_location_name]
          )
        end
        # rubcop:enable Metrics/MethodLength

        def appointment_type(request, klass)
          # this is temporary because test data does not include video type
          unless request[:visit_type].in?(['Office Visit', 'Express Care', 'Phone Call'])
            log_message_to_sentry('Unknown appointment request type', :error, { visit_type: request[:visit_type] })
          end
          klass::APPOINTMENT_TYPE
        end

        def phone_only?(request)
          request[:visit_type] == 'Phone Call'
        end

        def proposed_times(request)
          [
            { date: proposed_date(request[:option_date1]), time: proposed_time(request[:option_time1]) },
            { date: proposed_date(request[:option_date2]), time: proposed_time(request[:option_time2]) },
            { date: proposed_date(request[:option_date3]), time: proposed_time(request[:option_time3]) }
          ]
        end

        def proposed_date(date)
          date == 'No Date Selected' ? nil : date
        end

        def proposed_time(time)
          time == 'No Time Selected' ? nil : time
        end

        # this is used for sorting requests into appointments list
        # if all proposed times times are in the past, use the chronologically first proposed time
        # if any proposed times are in the future, use the one that occurs soonest
        # because we only have date an AM/PM, setting to 8AM and 12PM because when creating appointment
        def localized_start_date(request)
          time_zone = time_zone(request) || '+00:00'
          proposed_times = (1..3).each_with_object([]) do |i, results|
            date = request["option_date#{i}"]
            next if date.in?([nil, 'No Date Selected'])

            month, day, year = date.split('/').map(&:to_i)
            hour = request["option_time#{i}"] == 'AM' ? 8 : 12

            results << DateTime.new(year, month, day, hour, 0).in_time_zone(time_zone)
          end.sort

          current_time = Time.current.in_time_zone(time_zone)
          future_times = proposed_times.select { |time| time >= current_time }
          future_times.any? ? future_times.first : proposed_times.first
        end

        def status(request)
          request[:status].upcase
        end

        def status_detail(request)
          return nil unless request[:status] == 'Cancelled'

          first_detail = request.dig(:appointment_request_detail_code, 0)
          cancellation_code = first_detail&.dig(:detail_code, :code)
          return nil unless cancellation_code

          case cancellation_code
          when 'DETCODE22', 'DETCODE8'
            'CANCELLED BY PATIENT'
          when 'DETCODE19'
            'CANCELLED BY CLINIC'
          when 'DETCODE24'
            'CANCELLED - OTHER'
          else
            log_message_to_sentry('Unknown appointment request cancellation code', :error, { detail: first_detail })
            'CANCELLED - OTHER'
          end
        end

        # this is not correct for cc appointment requests, but it's the best approximation we can do at this time
        def time_zone(request)
          facility_id = request.dig(:facility, :parent_site_code)
          facility = Mobile::VA_FACILITIES_BY_ID["dfn-#{facility_id}"]
          facility ? facility[:time_zone] : nil
        end

        class VA
          APPOINTMENT_TYPE = 'VA'

          def self.provider_name(_)
            nil
          end

          def self.practice_name(_)
            nil
          end

          def self.facility_id(request)
            Mobile::V0::Appointment.toggle_non_prod_id!(request.dig(:facility, :facility_code))
          end

          def self.location(request)
            facility_id = facility_id(request)
            facility = Mobile::VA_FACILITIES_BY_ID["dfn-#{facility_id}"]
            {
              id: facility_id,
              name: facility ? facility[:name] : nil,
              address: {
                street: nil,
                city: nil,
                state: nil,
                zip_code: nil
              },
              lat: nil,
              long: nil,
              phone: {
                area_code: nil,
                number: nil,
                extension: nil
              },
              url: nil,
              code: nil
            }
          end
        end
        # rubocop:enable Metrics/MethodLength

        class CC
          APPOINTMENT_TYPE = 'COMMUNITY_CARE'

          def self.provider_name(request)
            provider_section = request.dig(:cc_appointment_request, :preferred_providers, 0)
            return nil if provider_section.nil?

            return nil if provider_section[:first_name].blank? && provider_section[:last_name].blank?

            "#{provider_section[:first_name]} #{provider_section[:last_name]}".strip
          end

          def self.practice_name(request)
            request.dig(:cc_appointment_request, :preferred_providers, 0, :practice_name)
          end

          def self.facility_id(_)
            nil
          end

          # rubocop:disable Metrics/MethodLength
          def self.location(request)
            source = request.dig(:cc_appointment_request, :preferred_providers, 0, :address) || {}
            phone_captures = phone_captures(request)
            {
              id: nil,
              name: practice_name(request),
              address: {
                street: source[:street],
                city: source[:city],
                state: source[:state],
                zip_code: source[:zip_code]
              },
              lat: nil,
              long: nil,
              phone: {
                area_code: phone_captures[1].presence,
                number: phone_captures[2].presence,
                extension: phone_captures[3].presence
              },
              url: nil,
              code: nil
            }
          end
          # rubocop:enable Metrics/MethodLength

          def self.phone_captures(request)
            # captures area code \((\d{3})\) number (after space) \s(\d{3}-\d{4})
            # and extension (until the end of the string) (\S*)\z
            request[:phone_number].match(/\((\d{3})\)\s(\d{3}-\d{4})(\S*)\z/)
          end
        end
      end
    end
  end
end
