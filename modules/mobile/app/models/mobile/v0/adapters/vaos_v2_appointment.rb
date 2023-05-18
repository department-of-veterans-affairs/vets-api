# frozen_string_literal: true

module Mobile
  module V0
    module Adapters
      class VAOSV2Appointment
        APPOINTMENT_TYPES = {
          va: 'VA',
          cc: 'COMMUNITY_CARE',
          va_video_connect_home: 'VA_VIDEO_CONNECT_HOME',
          va_video_connect_gfe: 'VA_VIDEO_CONNECT_GFE',
          va_video_connect_atlas: 'VA_VIDEO_CONNECT_ATLAS'
        }.freeze

        HIDDEN_STATUS = %w[
          noshow
          pending
        ].freeze

        STATUSES = {
          booked: 'BOOKED',
          fulfilled: 'BOOKED',
          arrived: 'BOOKED',
          cancelled: 'CANCELLED',
          hidden: 'HIDDEN',
          proposed: 'SUBMITTED'
        }.freeze

        CANCELLATION_REASON = {
          pat: 'CANCELLED BY PATIENT',
          prov: 'CANCELLED BY CLINIC'
        }.freeze

        CONTACT_TYPE = {
          phone: 'phone',
          email: 'email'
        }.freeze

        VIDEO_GFE_CODE = 'MOBILE_GFE'
        PHONE_KIND = 'phone'
        COVID_SERVICE = 'covid'

        # Only a subset of types of service that requires human readable conversion
        SERVICE_TYPES = {
          'amputation' => 'Amputation care',
          'audiology' => 'Audiology and speech (including hearing aid support)',
          'audiology-routine exam' => 'Routine hearing exam',
          'CCAUDRTNE' => 'Routine hearing exam',
          'audiology-hearing aid support' => 'Hearing aid support',
          'CCAUDHEAR' => 'Hearing aid support',
          'clinicalPharmacyPrimaryCare' => 'Pharmacy',
          'covid' => 'COVID-19 vaccine',
          'cpap' => 'Continuous Positive Airway Pressure (CPAP)',
          'foodAndNutrition' => 'Nutrition and Food',
          'moveProgram' => 'MOVE! weight management program',
          'ophthalmology' => 'Ophthalmology',
          'podiatry' => 'Podiatry',
          'CCPOD' => 'Podiatry',
          'optometry' => 'Optometry',
          'CCOPT' => 'Optometry',
          'outpatientMentalHealth' => 'Mental Health',
          'primaryCare' => 'Primary Care',
          'CCPRMYRTNE' => 'Primary Care',
          'homeSleepTesting' => 'Sleep medicine and home sleep testing',
          'socialWork' => 'Social Work'
        }.freeze

        REASONS = {
          'ROUTINEVISIT' => 'Routine Follow-up',
          'MEDICALISSUE' => 'New problem',
          'QUESTIONMEDS' => 'Medication concern',
          'OTHER_REASON' => 'My reason isn’t listed'
        }.freeze

        attr_reader :appointment

        def initialize(appointment)
          @appointment = appointment
        end

        # rubocop:disable Metrics/MethodLength
        def build_appointment_model
          adapted_appointment = {
            id: appointment[:id],
            appointment_type:,
            cancel_id:,
            comment:,
            facility_id:,
            sta6aid: facility_id,
            healthcare_provider: appointment[:healthcare_provider],
            healthcare_service:,
            location:,
            minutes_duration: minutes_duration(appointment[:minutes_duration]),
            phone_only: appointment[:kind] == PHONE_KIND,
            start_date_local: start_date_utc&.in_time_zone(timezone),
            start_date_utc:,
            status:,
            status_detail: cancellation_reason(appointment[:cancelation_reason]),
            time_zone: timezone,
            vetext_id: nil,
            reason:,
            is_covid_vaccine: appointment[:service_type] == COVID_SERVICE,
            is_pending: requested_periods.present?,
            proposed_times:,
            type_of_care: type_of_care(appointment[:service_type]),
            patient_phone_number:,
            patient_email:,
            best_time_to_call: appointment[:preferred_times_for_phone_call],
            friendly_location_name:
          }

          StatsD.increment('mobile.appointments.type', tags: ["type:#{appointment_type}"])
          Rails.logger.info('metric.mobile.appointment.type', type: appointment_type)
          Rails.logger.info('metric.mobile.appointment.upstream_status', status: appointment[:status])

          Mobile::V0::Appointment.new(adapted_appointment)
        end
        # rubocop:enable Metrics/MethodLength

        private

        def friendly_location_name
          return location[:name] if va_appointment?

          appointment.dig(:extension, :cc_location, :practice_name)
        end

        def patient_phone_number
          phone_number = if reason_code_contains_embedded_data?
                           embedded_data[:phone]
                         else
                           contact(appointment.dig(:contact, :telecom), CONTACT_TYPE[:phone])
                         end

          return nil unless phone_number

          parsed_phone = parse_phone(phone_number)
          joined_phone = "#{parsed_phone[:area_code]}-#{parsed_phone[:number]}"
          joined_phone += "x#{parsed_phone[:extension]}" if parsed_phone[:extension]
          joined_phone
        end

        def facility_id
          @facility_id ||= Mobile::V0::Appointment.convert_from_non_prod_id!(appointment[:location_id])
        end

        def timezone
          @timezone ||= begin
            time_zone = appointment.dig(:location, :time_zone, :time_zone_id)
            return time_zone if time_zone

            return nil unless facility_id

            # not always correct if clinic is different time zone than parent
            facility = Mobile::VA_FACILITIES_BY_ID["dfn-#{facility_id[0..2]}"]
            facility ? facility[:time_zone] : nil
          end
        end

        def cancel_id
          return nil unless appointment[:cancellable]

          appointment[:id]
        end

        def type_of_care(service_type)
          return nil if service_type.nil?

          SERVICE_TYPES[service_type] || service_type.titleize
        end

        def cancellation_reason(cancellation_reason)
          return nil if cancellation_reason.nil?

          cancel_code = cancellation_reason.dig(:coding, 0, :code)
          CANCELLATION_REASON[cancel_code&.to_sym]
        end

        def contact(telecom, type)
          return nil if telecom.blank?

          telecom.select { |contact| contact[:type] == type }&.dig(0, :value)
        end

        def proposed_times
          return nil if requested_periods.nil?

          requested_periods.map do |period|
            date, time = if reason_code_contains_embedded_data?
                           period.split(' ')
                         else
                           start_date = time_to_datetime(period[:start])
                           date = start_date.strftime('%m/%d/%Y')
                           time = start_date.hour.zero? ? 'AM' : 'PM'
                           [date, time]
                         end

            {
              date:,
              time:
            }
          end
        end

        def status
          return STATUSES[:hidden] if HIDDEN_STATUS.include?(appointment[:status])

          STATUSES[appointment[:status].to_sym]
        end

        def requested_periods
          @requested_periods ||= begin
            if reason_code_contains_embedded_data?
              date_string = embedded_data[:preferred_dates]
              return date_string&.split(',')
            end

            appointment[:requested_periods]
          end
        end

        def start_date_utc
          @start_date_utc ||= begin
            start = appointment[:start]
            if start.nil?
              sorted_dates = requested_periods.map { |period| time_to_datetime(period[:start]) }.sort
              future_dates = sorted_dates.select { |period| period > DateTime.now }
              future_dates.any? ? future_dates.first : sorted_dates.first
            else
              time_to_datetime(start)
            end
          end
        end

        def appointment_type
          case appointment[:kind]
          when 'phone', 'clinic'
            APPOINTMENT_TYPES[:va]
          when 'cc'
            APPOINTMENT_TYPES[:cc]
          when 'telehealth'
            if appointment.dig(:telehealth, :vvs_kind) == VIDEO_GFE_CODE
              APPOINTMENT_TYPES[:va_video_connect_gfe]
            elsif appointment.dig(:telehealth, :atlas)
              APPOINTMENT_TYPES[:va_video_connect_atlas]
            else
              APPOINTMENT_TYPES[:va_video_connect_home]
            end
          else
            APPOINTMENT_TYPES[:va]
          end
        end

        # rubocop:disable Metrics/MethodLength
        def location
          @location ||= begin
            location = {
              id: nil,
              name: nil,
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

            case appointment_type
            when APPOINTMENT_TYPES[:cc]
              cc_location = appointment.dig(:extension, :cc_location)

              if cc_location.present?
                location[:name] = cc_location[:practice_name]
                location[:address] = {
                  street: cc_location.dig(:address, :line)&.join(' ')&.strip,
                  city: cc_location.dig(:address, :city),
                  state: cc_location.dig(:address, :state),
                  zip_code: cc_location.dig(:address, :postal_code)
                }
                if cc_location[:telecom].present?
                  phone_number = cc_location[:telecom]&.find do |contact|
                    contact[:system] == CONTACT_TYPE[:phone]
                  end&.dig(:value)

                  location[:phone] = parse_phone(phone_number)
                end

              end
            when APPOINTMENT_TYPES[:va_video_connect_atlas],
              APPOINTMENT_TYPES[:va_video_connect_home],
              APPOINTMENT_TYPES[:va_video_connect_gfe]

              location[:name] = appointment.dig(:location, :name)
              location[:phone] = parse_phone(appointment.dig(:location, :phone, :main))
              telehealth = appointment[:telehealth]

              if telehealth
                address = telehealth.dig(:atlas, :address)

                if address
                  location[:address] = {
                    street: address[:street_address],
                    city: address[:city],
                    state: address[:state],
                    zip_code: address[:zip_code],
                    country: address[:country]
                  }
                end
                location[:url] = telehealth[:url]
                location[:code] = telehealth.dig(:atlas, :confirmation_code)
              end
            else
              location[:id] = appointment.dig(:location, :id)
              location[:name] = appointment.dig(:location, :name)
              address = appointment.dig(:location, :physical_address)
              if address.present?
                location[:address] = {
                  street: address[:line]&.join(' ')&.strip,
                  city: address[:city],
                  state: address[:state],
                  zip_code: address[:postal_code]
                }
              end
              location[:lat] = appointment.dig(:location, :lat)
              location[:long] = appointment.dig(:location, :long)
              location[:phone] = parse_phone(appointment.dig(:location, :phone, :main))
            end

            location
          end
        end
        # rubocop:enable Metrics/MethodLength

        def parse_phone(phone)
          # captures area code (\d{3}) number (\d{3}-\d{4})
          # and optional extension (until the end of the string) (?:\sx(\d*))?$
          phone_captures = phone&.match(/^\(?(\d{3})\)?.?(\d{3})-?(\d{4})(?:\sx(\d*))?$/)

          if phone_captures.nil?
            Rails.logger.warn(
              'mobile appointments failed to parse VAOS V2 phone number',
              phone:
            )
            return { area_code: nil, number: nil, extension: nil }
          end

          {
            area_code: phone_captures[1].presence,
            number: "#{phone_captures[2].presence}-#{phone_captures[3].presence}",
            extension: phone_captures[4].presence
          }
        end

        def healthcare_service
          if va_appointment?
            appointment[:service_name] || appointment[:physical_location]
          else
            appointment.dig(:extension, :cc_location, :practice_name)
          end
        end

        def minutes_duration(minutes_duration)
          # not in raw data, matches va.gov default for cc appointments
          return 60 if appointment_type == APPOINTMENT_TYPES[:cc] && minutes_duration.nil?

          minutes_duration
        end

        def va_appointment?
          [APPOINTMENT_TYPES[:va],
           APPOINTMENT_TYPES[:va_video_connect_gfe],
           APPOINTMENT_TYPES[:va_video_connect_atlas],
           APPOINTMENT_TYPES[:va_video_connect_home]].include?(appointment_type)
        end

        def comment
          return embedded_data[:comment] if reason_code_contains_embedded_data?

          appointment[:comment] || appointment.dig(:reason_code, :text)
        end

        def reason
          return REASONS[embedded_data[:reason_code]] if reason_code_contains_embedded_data?

          appointment.dig(:reason_code, :coding, 0, :code)
        end

        def patient_email
          return embedded_data[:email] if reason_code_contains_embedded_data?

          contact(appointment.dig(:contact, :telecom), CONTACT_TYPE[:email])
        end

        # the upstream server that hosts VA appointment requests (acheron) does not support some fields
        # so the front end puts all of that data into a comment, which is returned from upstream
        # as reason_code text. We must parse out some parts of that data. If any of those values is
        # present, we assume it's an acheron appointment and use only acheron values for relevant attributes.
        def reason_code_contains_embedded_data?
          @reason_code_contains_embedded_data ||= embedded_data.values.any?
        end

        def embedded_data
          @embedded_data ||= {
            phone: embedded_data_match('phone number'),
            email: embedded_data_match('email'),
            preferred_dates: embedded_data_match('preferred dates'),
            reason_code: embedded_data_match('reason code'),
            comment: embedded_data_match('comments')
          }
        end

        def embedded_data_match(key)
          match = appointment.dig(:reason_code, :text)&.match(/(^|\|)#{key}:?(.*?)(\||$)/)
          return nil unless match

          match[2].strip.presence
        end

        def time_to_datetime(time)
          time.is_a?(DateTime) ? time : DateTime.parse(time)
        end
      end
    end
  end
end
