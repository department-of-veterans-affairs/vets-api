# frozen_string_literal: true

require 'common/exceptions'

module VAOS
  module V2
    module CommunityCare
      class AppointmentCoordinator
        attr_reader :eps_failure

        def initialize(user)
          @user = user
          @eps_failure = nil
        end

        def merge_eps_into_list(appointments)
          eps_appts = fetch_eps_appointments_for_merge
          merged = merge_appointments(eps_appts, appointments)
          log_final_eps_state(merged)
          merged
        end

        def referral_already_used?(referral_id, pagination_params = {})
          unless eps_appointment_service.config.mock_enabled?
            vaos_response = appointments_service.get_all_appointments(pagination_params)
            vaos_request_failures = vaos_response[:meta][:failures]
            vaos_data = vaos_response[:data]

            unless vaos_data.is_a?(Array)
              Rails.logger.error(
                "#{self.class.name}#referral_already_used?: " \
                "Unexpected VAOS response format: data is #{vaos_data.class.name}, expected Array"
              )
              msg = 'Unexpected VAOS response in referral_already_used? - data is not an Array'
              vaos_request_failures = msg if vaos_request_failures.blank?
            end

            return { error: true, failures: vaos_request_failures } if vaos_request_failures.present?

            return { exists: true } if vaos_data.any? { |appt| appt[:referral_id] == referral_id }
          end

          eps_appointments = eps_appointment_service.get_appointments(referral_number: referral_id)
          non_draft = eps_appointments&.reject { |appt| appt[:state] == 'draft' } || []
          { exists: non_draft.any? }
        end

        def appointments_for_referral(referral_number)
          start_time = Time.current
          eps_appointments = fetch_and_normalize_eps_appointments(referral_number)
          vaos_appointments = fetch_and_normalize_vaos_appointments(referral_number)

          StatsD.histogram('vaos.get_active_appointments_for_referral.duration',
                           (Time.current - start_time) * 1000)

          log_status_discrepancies(eps_appointments, vaos_appointments, referral_number)

          {
            EPS: { data: eps_appointments },
            VAOS: { data: vaos_appointments }
          }
        end

        private

        attr_reader :user

        # --- Index merge helpers ---

        def fetch_eps_appointments_for_merge
          raw_appts = eps_appointment_service.get_appointments_with_providers
          return [] if raw_appts.blank?

          kept, removed = separate_by_start_time(raw_appts)
          log_appointment_separation(kept, removed)
          kept
        rescue Common::Exceptions::BackendServiceException, Common::Client::Errors::ClientError,
               Common::Exceptions::GatewayTimeout, Timeout::Error, Faraday::ConnectionFailed => e
          Rails.logger.error("EPS Debug: Failed to fetch EPS appointments: #{e.class} - #{e.message}")
          @eps_failure = { source: 'EPS', detail: 'EPS appointment data unavailable' }
          []
        end

        def merge_appointments(eps_appointments, appointments)
          normalized_new = eps_appointments.map(&:serializable_hash)
          existing_referral_ids = appointments.to_set { |a| a.dig(:referral, :referral_number) }
          existing_start_times = appointments.pluck(:start)

          rejected_ids = []
          merged = appointments + normalized_new.reject do |a|
            duplicate = existing_referral_ids.include?(a.dig(:referral, :referral_number)) &&
                        existing_start_times.include?(a[:start])
            rejected_ids << a[:id] if duplicate
            duplicate
          end

          log_merge_results(normalized_new, rejected_ids)
          merged.sort_by { |appt| appt[:start] || '' }
        end

        def separate_by_start_time(appointments)
          kept = []
          removed = []

          appointments.each do |appt|
            if appt.start.present?
              kept << appt
            else
              removed << appt
            end
          end

          [kept, removed]
        end

        # --- Referral query helpers ---

        def fetch_and_normalize_eps_appointments(referral_number)
          raw = eps_appointment_service.get_appointments(referral_number:)
          filtered = raw.reject { |appt| appt[:state] == 'draft' }
          normalized = filtered.map do |appt|
            {
              id: appt[:id],
              status: normalize_eps_status(appt),
              start: appt.dig(:appointment_details, :start),
              provider_service_id: appt[:provider_service_id],
              last_retrieved: appt.dig(:appointment_details, :last_retrieved)
            }
          end

          deduped = deduplicate_eps_appointments(normalized)
          deduped.sort_by { |appt| appt[:start] || '' }.reverse
        rescue Common::Exceptions::BackendServiceException => e
          log_fetch_error('EPS', referral_number, e.class.name.to_s)
          raise
        end

        def fetch_and_normalize_vaos_appointments(referral_number)
          vaos_response = appointments_service.get_all_appointments({})
          check_vaos_response_for_failures(vaos_response, referral_number)
          process_vaos_appointments(vaos_response[:data], referral_number)
        rescue Common::Exceptions::BackendServiceException => e
          log_fetch_error('VAOS', referral_number, e.class.name.to_s)
          raise
        end

        def check_vaos_response_for_failures(vaos_response, referral_number)
          return if vaos_response[:meta][:failures].blank?

          log_fetch_error('VAOS', referral_number, vaos_response[:meta][:failures])
          raise Common::Exceptions::BackendServiceException.new('VAOS_502',
                                                                { detail: vaos_response[:meta][:failures].to_s })
        end

        def process_vaos_appointments(appointments_data, referral_number)
          unless appointments_data.is_a?(Array)
            Rails.logger.warn('VAOS process_vaos_appointments - appointments_data is not an array')
            return []
          end

          filtered = appointments_data.select { |appt| appt[:referral_id] == referral_number }
          normalized = filtered.map do |appt|
            {
              id: appt[:id],
              status: normalize_vaos_status(appt),
              start: appt[:start],
              created: appt[:created]
            }
          end

          deduped = deduplicate_vaos_appointments(normalized)
          deduped.sort_by { |appt| appt[:start] || '' }.reverse
        end

        def normalize_eps_status(appointment)
          appointment.dig(:appointment_details, :status) == 'cancelled' ? 'cancelled' : 'active'
        end

        def normalize_vaos_status(appointment)
          appointment[:status] == 'cancelled' ? 'cancelled' : 'active'
        end

        def deduplicate_eps_appointments(appointments)
          appointments.group_by { |appt| [appt[:start], appt[:provider_service_id]] }.map do |_key, dupes|
            next dupes.first if dupes.size == 1

            active = dupes.select { |appt| appt[:status] == 'active' }
            (active.any? ? active : dupes).max_by { |appt| appt[:last_retrieved] || '' }
          end
        end

        def deduplicate_vaos_appointments(appointments)
          appointments.group_by { |appt| appt[:start] }.map do |_key, dupes|
            next dupes.first if dupes.size == 1

            active = dupes.select { |appt| appt[:status] == 'active' }
            (active.any? ? active : dupes).max_by { |appt| appt[:created] || '' }
          end
        end

        # --- Shared logging ---

        def log_status_discrepancies(eps_appointments, vaos_appointments, referral_number)
          eps_by_start = eps_appointments.group_by { |appt| appt[:start] }
          vaos_by_start = vaos_appointments.group_by { |appt| appt[:start] }

          (eps_by_start.keys & vaos_by_start.keys).each do |start_time|
            eps_statuses = eps_by_start[start_time].map { |appt| appt[:status] }.uniq
            vaos_statuses = vaos_by_start[start_time].map { |appt| appt[:status] }.uniq

            next if eps_statuses == vaos_statuses

            masked_referral = referral_number&.last(4) || 'unknown'
            Rails.logger.warn('Appointment status discrepancy between EPS and VAOS',
                              { referral_ending_in: masked_referral, start_time:,
                                eps_statuses:, vaos_statuses: })
          end
        end

        def log_fetch_error(source, referral_number, error_details)
          masked_referral = "***#{referral_number.to_s.last(4)}"
          Rails.logger.error(
            "Failed to fetch #{source} appointments for referral #{masked_referral}: #{error_details}"
          )
        end

        def extract_facility_identifiers(appointments)
          appointments.map do |appt|
            if appt.is_a?(Hash)
              if appt.dig(:location, 'name') && appt.dig(:location, 'id')
                "#{appt[:location]['name']} (#{appt[:location]['id']})"
              elsif appt[:location_id]
                "facility #{appt[:location_id]}"
              else
                'unknown facility'
              end
            else
              location_id = appt.try(:location_id) || appt.try(:[], :location_id)
              location_id ? "facility #{location_id}" : 'unknown facility'
            end
          end
        end

        def eps_appointments_filter(appointments)
          appointments.select do |appt|
            appt[:type] == 'epsAppointment' || appt.dig(:provider, :id).present?
          end
        end

        def log_merge_results(normalized_new, rejected_ids)
          kept = normalized_new.reject { |appt| rejected_ids.include?(appt[:id]) }
          rejected = normalized_new.select { |appt| rejected_ids.include?(appt[:id]) }
          kept_facilities = extract_facility_identifiers(kept)
          rejected_facilities = extract_facility_identifiers(rejected)
          duplicates_msg = rejected_facilities.any? ? ", removed duplicates #{rejected_facilities}" : ''
          Rails.logger.info("EPS Debug: Merge kept #{kept_facilities}#{duplicates_msg}")
        end

        def log_appointment_separation(kept, removed)
          removed_facilities = extract_facility_identifiers(removed)
          kept_facilities = extract_facility_identifiers(kept)
          removed_msg = removed_facilities.any? ? ", removed #{removed_facilities}" : ''
          Rails.logger.info("EPS Debug: Kept #{kept_facilities}#{removed_msg}")
        end

        def log_final_eps_state(appointments)
          final_facilities = extract_facility_identifiers(eps_appointments_filter(appointments))
          Rails.logger.info("EPS Debug: Final response #{final_facilities.any? ? final_facilities : 'none'}")
        end

        # --- Service dependencies ---

        def appointments_service
          @appointments_service ||= VAOS::V2::AppointmentsService.new(user)
        end

        def eps_appointment_service
          @eps_appointment_service ||= Eps::AppointmentService.new(user)
        end
      end
    end
  end
end
