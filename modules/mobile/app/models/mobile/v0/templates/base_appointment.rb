# frozen_string_literal: true

module Mobile
  module V0
    module Templates
      class BaseAppointment
        attr :appointment_type,
             :provider_name,
             :practice_name,
             :facility_id,
             :location,
             :request

        def self.status(request)
          request[:status].upcase
        end

        def initialize(request)
          @request = request
        end

        # rubocop:disable Metrics/MethodLength
        def appointment
          Mobile::V0::Appointment.new(
            id: @request[:appointment_request_id],
            appointment_type:,
            cancel_id: @request[:appointment_request_id],
            comment: nil,
            facility_id:,
            sta6aid: nil,
            healthcare_provider: provider_name,
            healthcare_service: practice_name,
            location:,
            minutes_duration: nil,
            phone_only: phone_only?,
            start_date_local: localized_start_date,
            start_date_utc: localized_start_date.utc,
            status: self.class.status(@request),
            status_detail:,
            time_zone: request_time_zone,
            vetext_id: nil,
            reason: @request[:purpose_of_visit],
            is_covid_vaccine: nil,
            is_pending: true,
            proposed_times:,
            type_of_care: @request[:appointment_type],
            patient_phone_number: @request[:phone_number],
            patient_email: @request[:email],
            best_time_to_call: @request[:best_timeto_call],
            friendly_location_name: @request[:friendly_location_name]
          )
        end
        # rubocop:enable Metrics/MethodLength

        private

        def phone_only?
          @request[:visit_type] == 'Phone Call'
        end

        def proposed_times
          [
            { date: proposed_date(@request[:option_date1]), time: proposed_time(@request[:option_time1]) },
            { date: proposed_date(@request[:option_date2]), time: proposed_time(@request[:option_time2]) },
            { date: proposed_date(@request[:option_date3]), time: proposed_time(@request[:option_time3]) }
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
        def localized_start_date
          time_zone = request_time_zone || '+00:00'
          proposed_times = (1..3).each_with_object([]) do |i, results|
            date = @request["option_date#{i}"]
            next if date.in?([nil, 'No Date Selected'])

            month, day, year = date.split('/').map(&:to_i)
            hour = @request["option_time#{i}"] == 'AM' ? 8 : 12

            results << DateTime.new(year, month, day, hour, 0).in_time_zone(time_zone)
          end.sort

          current_time = Time.current.in_time_zone(time_zone)
          future_times = proposed_times.select { |time| time >= current_time }
          future_times.any? ? future_times.first : proposed_times.first
        end

        def status_detail
          return nil unless @request[:status] == 'Cancelled'

          first_detail = @request.dig(:appointment_request_detail_code, 0)
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
            Rails.logger.error('Unknown appointment request cancellation code', :error,
                               { appointment_request_id: @request[:appointment_request_id], detail: first_detail })
            'CANCELLED - OTHER'
          end
        end

        # this is not correct for cc appointment requests, but it's the best approximation we can do at this time
        def request_time_zone
          facility_id = @request.dig(:facility, :parent_site_code)
          facility = Mobile::VA_FACILITIES_BY_ID["dfn-#{facility_id}"]
          facility ? facility[:time_zone] : nil
        end
      end
    end
  end
end
