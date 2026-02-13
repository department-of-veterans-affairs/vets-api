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
          va_video_connect_atlas: 'VA_VIDEO_CONNECT_ATLAS',
          va_video_connect_onsite: 'VA_VIDEO_CONNECT_ONSITE'
        }.freeze

        STATUSES = {
          booked: 'BOOKED',
          fulfilled: 'BOOKED',
          arrived: 'BOOKED',
          cancelled: 'CANCELLED',
          noshow: 'HIDDEN',
          pending: 'HIDDEN',
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

        PHONE_KIND = 'phone'
        COVID_SERVICE = 'covid'
        VIDEO_CONNECT_AT_VA = %w[
          STORE_FORWARD
          CLINIC_BASED
        ].freeze

        # ADHOC is a staging value used in place of MOBILE_ANY
        VIDEO_CODE = %w[
          ADHOC
          MOBILE_ANY
          MOBILE_ANY_GROUP
          MOBILE_GFE
        ].freeze

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
            appointment_ien: appointment[:ien],
            cancel_id:,
            comment: appointment[:patient_comments],
            facility_id:,
            sta6aid: facility_id,
            healthcare_provider:,
            healthcare_service: nil, # set to nil because it is deprecated
            location:,
            physical_location: appointment[:physical_location],
            minutes_duration: appointment[:minutes_duration],
            phone_only: appointment[:kind] == PHONE_KIND,
            start_date_local:,
            start_date_utc:,
            status:,
            status_detail: cancellation_reason(appointment[:cancelation_reason]),
            time_zone: timezone,
            vetext_id:,
            reason: appointment[:reason_for_appointment],
            is_covid_vaccine: appointment[:service_type] == COVID_SERVICE,
            is_pending: appointment_request?,
            proposed_times:,
            type_of_care: appointment[:type_of_care],
            patient_phone_number:,
            patient_email:,
            best_time_to_call: appointment[:preferred_times_for_phone_call],
            friendly_location_name:,
            service_category_name: appointment.dig(:service_category, 0, :text),
            show_schedule_link: appointment[:show_schedule_link],
            is_cerner: appointment[:is_cerner],
            avs_pdf: appointment[:avs_pdf],
            avs_error: appointment[:avs_error]
          }

          if appointment[:travelPayClaim]
            adapted_appointment[:travelPayClaim] =
              appointment[:travelPayClaim].deep_symbolize_keys
            # Using the existence of the travelPayClaim key as a flag for if we should check for eligibility
            # since that indicates that the include_claims flag is true and it's a Past appointment
            adapted_appointment[:travel_pay_eligible] = travel_pay_eligible?
          end

          StatsD.increment('mobile.appointments.type', tags: ["type:#{appointment_type}"])

          Mobile::V0::Appointment.new(adapted_appointment)
        end

        # rubocop:enable Metrics/MethodLength

        private

        def appointment_request?
          appointment[:requested_periods].present?
        end

        # to match web behavior, prefer the value found in the practitioners list over the preferred_provider_name.
        # Unlike web, we want to remove the not found message because it's too long and may cause formatting issues.
        def healthcare_provider
          practitioner_name = find_practitioner_name(appointment[:practitioners])
          return practitioner_name if practitioner_name

          return nil if appointment[:preferred_provider_name] == VAOS::V2::AppointmentProviderName::NPI_NOT_FOUND_MSG

          appointment[:preferred_provider_name]
        end

        def find_practitioner_name(practitioner_list)
          practitioner_list&.find do |practitioner|
            first_name = practitioner.dig(:name, :given)&.join(' ')&.strip
            last_name = practitioner.dig(:name, :family)
            name = [first_name, last_name].compact.join(' ')
            return name if name.present?
          end
        end

        # this does not match the way friendly name is set for web.
        # our mocks do not match the web mocks 1:1 so different data is needed
        def friendly_location_name
          if va_appointment? || appointment_request?
            return appointment[:service_name] || appointment.dig(:location,
                                                                 :name)
          end

          appointment.dig(:extension, :cc_location, :practice_name)
        end

        def patient_phone_number
          phone_number = contact(appointment.dig(:contact, :telecom), CONTACT_TYPE[:phone])

          return nil unless phone_number

          parsed_phone = parse_phone(phone_number)
          joined_phone = "#{parsed_phone[:area_code]}-#{parsed_phone[:number]}"
          joined_phone += "x#{parsed_phone[:extension]}" if parsed_phone[:extension]
          joined_phone
        end

        def facility_id
          @facility_id ||= Mobile::V0::Appointment.convert_from_non_prod_id!(appointment[:location_id])
        end

        def vetext_id
          @vetext_id ||= "#{facility_id};#{utc_to_fileman_date(start_date_local)}"
        end

        def utc_to_fileman_date(datetime)
          fileman_date = "#{datetime.year - 1700}#{format('%02d', datetime.month)}#{format('%02d', datetime.day)}"
          fileman_time = "#{format('%02d', datetime.hour)}#{format('%02d', datetime.min)}"
          "#{fileman_date}.#{fileman_time}".gsub(/0+$/, '').gsub(/\.$/, '.0')
        end

        def timezone
          @timezone ||= get_timezone
        end

        def get_timezone
          time_zone = appointment.dig(:location, :time_zone, :time_zone_id)
          return time_zone if time_zone

          return nil unless facility_id

          # not always correct if clinic is different time zone than parent
          facility = Mobile::VA_FACILITIES_BY_ID["dfn-#{facility_id[0..2]}"]
          facility ? facility[:time_zone] : nil
        end

        def cancel_id
          return nil unless cancellable?

          appointment[:id]
        end

        def cancellable?
          appointment[:cancellable] && appointment[:kind] != 'telehealth'
        end

        def cancellation_reason(cancellation_reason)
          if cancellation_reason.nil?
            return CANCELLATION_REASON[:prov] if status == STATUSES[:cancelled]

            return nil
          end

          cancel_code = cancellation_reason.dig(:coding, 0, :code)
          CANCELLATION_REASON[cancel_code&.to_sym]
        end

        def contact(telecom, type)
          return nil if telecom.blank?

          telecom.select { |contact| contact&.try(:dig, :type) == type }&.dig(0, :value)
        end

        def proposed_times
          return nil unless appointment[:requested_periods]

          appointment[:requested_periods].map do |period|
            start_date = time_to_datetime(period[:start])
            date = start_date.strftime('%m/%d/%Y')
            time = start_date.hour.zero? ? 'AM' : 'PM'
            { date:, time: }
          end
        end

        def status
          STATUSES[appointment[:status].to_sym]
        end

        def start_date_utc
          @start_date_utc ||= begin
            start = appointment[:start]
            if start.nil?
              sorted_dates = appointment[:requested_periods].map do |period|
                time_to_datetime(period[:start])
              end.sort
              future_dates = sorted_dates.select { |period| period > DateTime.now }
              future_dates.any? ? future_dates.first : sorted_dates.first
            else
              time_to_datetime(start)
            end
          end
        end

        def start_date_local
          @start_date_local ||= begin
            DateTime.parse(appointment[:local_start_time])
          rescue
            start_date_utc&.in_time_zone(timezone)
          end
        end

        def appointment_type
          case appointment[:type]
          when VAOS::V2::AppointmentsService::APPOINTMENT_TYPES[:cc_appointment],
            VAOS::V2::AppointmentsService::APPOINTMENT_TYPES[:cc_request]
            APPOINTMENT_TYPES[:cc]
          when VAOS::V2::AppointmentsService::APPOINTMENT_TYPES[:va]
            convert_va_appointment_type
          when VAOS::V2::AppointmentsService::APPOINTMENT_TYPES[:request]
            APPOINTMENT_TYPES[:va]
          else
            appointment[:type]
          end
        end

        def convert_va_appointment_type
          return appointment[:type] unless appointment[:kind] == 'telehealth'
          return APPOINTMENT_TYPES[:va_video_connect_atlas] if appointment.dig(:telehealth, :atlas)

          vvs_kind = appointment.dig(:telehealth, :vvs_kind)
          if VIDEO_CODE.include?(vvs_kind)
            if vvs_kind == 'MOBILE_GFE' || appointment.dig(:extension, :patient_has_mobile_gfe)
              APPOINTMENT_TYPES[:va_video_connect_gfe]
            else
              APPOINTMENT_TYPES[:va_video_connect_home]
            end
          elsif VIDEO_CONNECT_AT_VA.include?(vvs_kind)
            APPOINTMENT_TYPES[:va_video_connect_onsite]
          else
            vvs_video_appt = appointment.dig(:extension, :vvs_vista_video_appt)
            vvs_video_appt.to_s.downcase == 'true' ? APPOINTMENT_TYPES[:va_video_connect_home] : APPOINTMENT_TYPES[:va]
          end
        end

        def location
          @location ||= begin
            case appointment_type
            when APPOINTMENT_TYPES[:cc]
              appointment_request? ? set_cc_appointment_request_location : set_cc_appointment_location
            when APPOINTMENT_TYPES[:va_video_connect_atlas],
              APPOINTMENT_TYPES[:va_video_connect_home],
              APPOINTMENT_TYPES[:va_video_connect_gfe]
              set_telehealth_location
            else
              set_va_appointment_location
            end

            location_template
          end
        end

        def location_template
          @location_template ||= {
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
        end

        def set_cc_appointment_request_location
          practitioners_address = appointment.dig(:practitioners, 0, :address)
          return if practitioners_address.blank?

          location_template[:address][:street] = practitioners_address.dig(:line, 0)
          location_template[:address][:city] = practitioners_address[:city]
          location_template[:address][:state] = practitioners_address[:state]
          location_template[:address][:zip_code] = practitioners_address[:postal_code]
        end

        def set_cc_appointment_location
          cc_location = appointment.dig(:extension, :cc_location)
          return if cc_location.blank?

          location_template[:name] = cc_location[:practice_name]
          location_template[:address][:street] = cc_location.dig(:address, :line)&.join(' ')&.strip
          location_template[:address][:city] = cc_location.dig(:address, :city)
          location_template[:address][:state] = cc_location.dig(:address, :state)
          location_template[:address][:zip_code] = cc_location.dig(:address, :postal_code)

          return if cc_location[:telecom].blank?

          phone_number = cc_location[:telecom].find do |contact|
            contact[:system] == CONTACT_TYPE[:phone]
          end&.dig(:value)
          location_template[:phone] = parse_phone(phone_number)
        end

        def set_telehealth_location
          location_template[:name] = appointment.dig(:location, :name)
          location_template[:phone] = parse_phone(appointment.dig(:location, :phone, :main))
          telehealth = appointment[:telehealth]
          return if telehealth.blank?

          location_template[:url] = telehealth[:url]
          location_template[:code] = telehealth.dig(:atlas, :confirmation_code)

          address = telehealth.dig(:atlas, :address)
          return if address.blank?

          location_template[:address][:street] = address[:street_address]
          location_template[:address][:city] = address[:city]
          location_template[:address][:state] = address[:state]
          location_template[:address][:zip_code] = address[:zip_code]
          location_template[:address][:country] = address[:country]
        end

        def set_va_appointment_location
          location_template[:id] = appointment.dig(:location, :id)
          location_template[:name] = appointment.dig(:location, :name)
          location_template[:lat] = appointment.dig(:location, :lat)
          location_template[:long] = appointment.dig(:location, :long)
          location_template[:phone] = parse_phone(appointment.dig(:location, :phone, :main))

          address = appointment.dig(:location, :physical_address)
          return if address.blank?

          location_template[:address][:street] = address[:line]&.join(' ')&.strip
          location_template[:address][:city] = address[:city]
          location_template[:address][:state] = address[:state]
          location_template[:address][:zip_code] = address[:postal_code]
        end

        def parse_phone(phone)
          # captures area code (\d{3}) number (\d{3}-\d{4})
          # and optional extension (until the end of the string) (?:\sx(\d*))?$
          phone_captures = phone&.match(/^\(?(\d{3})\)?.?(\d{3})-?(\d{4})(?:\sx(\d*))?$/)

          unless phone_captures.nil?
            return {
              area_code: phone_captures[1].presence,
              number: "#{phone_captures[2].presence}-#{phone_captures[3].presence}",
              extension: phone_captures[4].presence
            }
          end

          { area_code: nil, number: nil, extension: nil }
        end

        def va_appointment?
          [APPOINTMENT_TYPES[:va],
           APPOINTMENT_TYPES[:va_video_connect_gfe],
           APPOINTMENT_TYPES[:va_video_connect_atlas],
           APPOINTMENT_TYPES[:va_video_connect_home],
           APPOINTMENT_TYPES[:va_video_connect_onsite]].include?(appointment_type)
        end

        def patient_email
          contact(appointment.dig(:contact, :telecom), CONTACT_TYPE[:email])
        end

        def reason_code_match(key)
          appointment.dig(:reason_code, :text)&.match(/(^|\|)#{key}:?(.*?)(\||$)/)
        end

        def time_to_datetime(time)
          time.is_a?(DateTime) ? time : DateTime.parse(time)
        end

        # checks for if the appointment type is eligible for travel pay
        def travel_pay_eligible?
          [APPOINTMENT_TYPES[:va], APPOINTMENT_TYPES[:va_video_connect_atlas],
           APPOINTMENT_TYPES[:va_video_connect_onsite]].include?(appointment_type) &&
            appointment[:kind] != PHONE_KIND &&
            appointment.status == 'booked' && # only confirmed (i.e. booked) appointments are eligible
            appointment.start < Time.now.utc && # verify it's a past appointment
            ## TODO: reduce duplication by address this on the app frontend with claim metadata
            TravelPay::DateUtils.valid_datetime?(appointment[:local_start_time].to_s)
        end
      end
    end
  end
end
