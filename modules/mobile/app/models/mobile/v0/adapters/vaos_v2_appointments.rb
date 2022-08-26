# frozen_string_literal: true

module Mobile
  module V0
    module Adapters
      # Due to backwards compatibility requirements, this adapter takes in VAOS V2
      # schema and outputs Mobile V0 appointments. Eventually this will be rolled
      # off in favor of Mobile Appointment V2 model.
      #
      # @example create a new instance and parse incoming data
      #   Mobile::V0::Adapters::VAOSV2Appointments.new.parse(appointments)
      #
      class VAOSV2Appointments
        APPOINTMENT_TYPES = {
          va: 'VA',
          cc: 'COMMUNITY_CARE',
          va_video_connect_home: 'VA_VIDEO_CONNECT_HOME',
          va_video_connect_gfe: 'VA_VIDEO_CONNECT_GFE',
          va_video_connect_atlas: 'VA_VIDEO_CONNECT_ATLAS'
        }.freeze

        HIDDEN_STATUS = %w[
          arrived
          noshow
          pending
        ].freeze

        STATUSES = {
          booked: 'BOOKED',
          fulfilled: 'BOOKED',
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

        # Takes a result set of VAOS v2 appointments from the appointments web service
        # and returns the set adapted to a common schema.
        #
        # @appointments Hash a list of variousappointment types
        #
        # @return Hash the adapted list
        #
        def parse(appointments = [])
          appointments.map do |appointment_hash|
            build_appointment_model(appointment_hash)
          rescue => e
            Rails.logger.error(
              'Error adapting VAOS v2 appointment into Mobile V0 appointment',
              appointment: appointment_hash, error: e.message, backtrace: e.backtrace
            )
            next
          end.compact
        end

        private

        # rubocop:disable Metrics/MethodLength
        def build_appointment_model(appointment_hash)
          facility_id = Mobile::V0::Appointment.convert_from_non_prod_id!(
            appointment_hash[:location_id]
          )
          sta6aid = facility_id
          type = parse_by_appointment_type(appointment_hash, appointment_hash[:kind])
          start_date_utc = start_date_utc(appointment_hash)
          time_zone = time_zone(facility_id)
          start_date_local = start_date_utc.in_time_zone(time_zone)
          status = status(appointment_hash)
          adapted_hash = {
            id: appointment_hash[:id],
            appointment_type: type,
            cancel_id: cancel_id(appointment_hash),
            comment: appointment_hash[:comment] || appointment_hash.dig(:reason_code, :text),
            facility_id: facility_id,
            sta6aid: sta6aid,
            healthcare_provider: healthcare_provider(appointment_hash[:practitioners]),
            healthcare_service: healthcare_service(appointment_hash, type),
            location: location(type, appointment_hash),
            minutes_duration: minutes_duration(appointment_hash[:minutes_duration], type),
            phone_only: appointment_hash[:kind] == PHONE_KIND,
            start_date_local: start_date_local,
            start_date_utc: start_date_utc,
            status: status,
            status_detail: cancellation_reason(appointment_hash[:cancelation_reason]),
            time_zone: time_zone,
            vetext_id: nil,
            reason: appointment_hash.dig(:reason_code, :coding, 0, :code),
            is_covid_vaccine: appointment_hash[:service_type] == COVID_SERVICE,
            is_pending: status == STATUSES[:proposed],
            proposed_times: proposed_times(appointment_hash[:requested_periods]),
            type_of_care: type_of_care(appointment_hash[:service_type], type),
            patient_phone_number: contact(appointment_hash.dig(:contact, :telecom), CONTACT_TYPE[:phone]),
            patient_email: contact(appointment_hash.dig(:contact, :telecom), CONTACT_TYPE[:email]),
            best_time_to_call: appointment_hash[:preferred_times_for_phone_call],
            friendly_location_name: appointment_hash.dig(:extension, :cc_location, :practice_name)
          }

          Rails.logger.info('metric.mobile.appointment.type', type: type)
          Rails.logger.info('metric.mobile.appointment.upstream_status', status: appointment_hash[:status])

          Mobile::V0::Appointment.new(adapted_hash)
        end
        # rubocop:enable Metrics/MethodLength

        def cancel_id(appointment_hash)
          return nil unless appointment_hash[:cancellable]

          appointment_hash[:id]
        end

        def type_of_care(service_type, type)
          va?(type) ? nil : service_type
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

        def proposed_times(requested_periods)
          return nil if requested_periods.nil?

          requested_periods.map do |period|
            start_date = DateTime.parse(period[:start])
            {
              date: start_date.strftime('%m/%d/%Y'),
              time: start_date.hour.zero? ? 'AM' : 'PM'
            }
          end
        end

        def status(appointment_hash)
          return STATUSES[:hidden] if HIDDEN_STATUS.include?(appointment_hash[:status])

          STATUSES[appointment_hash[:status].to_sym]
        end

        def start_date_utc(appointment_hash)
          start = appointment_hash[:start]
          if start.nil?
            sorted_dates = appointment_hash[:requested_periods].map { |period| DateTime.parse(period[:start]) }.sort
            future_dates = sorted_dates.select { |period| period > DateTime.now }
            future_dates.any? ? future_dates.first : sorted_dates.first
          else
            DateTime.parse(start)
          end
        end

        def parse_by_appointment_type(appointment_hash, type)
          case type
          when 'phone', 'clinic'
            APPOINTMENT_TYPES[:va]
          when 'cc'
            APPOINTMENT_TYPES[:cc]
          when 'telehealth'
            if appointment_hash.dig(:telehealth, :vvs_kind) == VIDEO_GFE_CODE
              APPOINTMENT_TYPES[:va_video_connect_gfe]
            elsif appointment_hash.dig(:telehealth, :atlas)
              APPOINTMENT_TYPES[:va_video_connect_atlas]
            else
              APPOINTMENT_TYPES[:va_video_connect_home]
            end
          end
        end

        # rubocop:disable Metrics/MethodLength
        def location(type, appointment_hash)
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
          telehealth = appointment_hash[:telehealth]

          case type
          when APPOINTMENT_TYPES[:cc]
            cc_location = appointment_hash.dig(:extension, :cc_location)

            if cc_location.present?
              location[:name] = cc_location[:practice_name]
              location[:address] = {
                street: cc_location.dig(:address, :line)&.join(' ')&.strip,
                city: cc_location.dig(:address, :city),
                state: cc_location.dig(:address, :state),
                zip_code: cc_location.dig(:address, :postal_code)
              }
            end
          when APPOINTMENT_TYPES[:va_video_connect_atlas],
            APPOINTMENT_TYPES[:va_video_connect_home],
            APPOINTMENT_TYPES[:va_video_connect_gfe]

            location[:name] = appointment_hash.dig(:location, :name)

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
            location[:id] = appointment_hash.dig(:location, :id)
            location[:name] = appointment_hash.dig(:location, :name)
            address = appointment_hash.dig(:location, :physical_address)
            if address.present?
              location[:address] = {
                street: address[:line]&.join(' ')&.strip,
                city: address[:city],
                state: address[:state],
                zip_code: address[:postal_code]
              }
            end
            location[:lat] = appointment_hash.dig(:location, :lat)
            location[:long] = appointment_hash.dig(:location, :long)
            location[:phone] = location_phone(appointment_hash)
          end

          location
        end
        # rubocop:enable Metrics/MethodLength

        def location_phone(appointment_hash)
          phone = appointment_hash.dig(:location, :phone, :main)

          # captures area code (\d{3}) number (\d{3}-\d{4})
          # and optional extension (until the end of the string) (?:\sx(\d*))?$
          phone_captures = phone&.match(/^(\d{3})-(\d{3}-\d{4})(?:\sx(\d*))?$/)

          if phone_captures.nil?
            Rails.logger.warn(
              'mobile appointments failed to parse VAOS V2 facility phone number',
              facility_id: appointment_hash.dig(:location, :id),
              facility_phone: phone
            )
            return { area_code: nil, number: nil, extension: nil }
          end

          {
            area_code: phone_captures[1].presence,
            number: phone_captures[2].presence,
            extension: phone_captures[3].presence
          }
        end

        def time_zone(facility_id)
          facility = Mobile::VA_FACILITIES_BY_ID["dfn-#{facility_id}"]
          facility ? facility[:time_zone] : nil
        end

        def healthcare_provider(practitioners)
          return nil if practitioners.nil? || practitioners.none? { |prac| prac[:name] }

          practitioners.map do |practitioner|
            first_name = practitioner.dig(:name, :given)&.join(' ')&.strip
            last_name = practitioner.dig(:name, :family)
            [first_name, last_name].compact.join(' ').presence
          end.compact.join(', ')
        end

        def healthcare_service(appointment_hash, type)
          if va?(type)
            appointment_hash[:service_name] || appointment_hash[:physical_location]
          else
            appointment_hash.dig(:extension, :cc_location, :practice_name)
          end
        end

        def minutes_duration(minutes_duration, type)
          # not in raw data, matches va.gov default for cc appointments
          return 60 if type == APPOINTMENT_TYPES[:cc] && minutes_duration.nil?

          minutes_duration
        end

        def va?(type)
          type == APPOINTMENT_TYPES[:va]
        end
      end
    end
  end
end
