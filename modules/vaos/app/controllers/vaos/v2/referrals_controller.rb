# frozen_string_literal: true

module VAOS
  module V2
    # ReferralsController provides endpoints for fetching CCRA referrals
    # It uses the Ccra::ReferralService to interact with the underlying CCRA API
    class ReferralsController < VAOS::BaseController
      include VAOS::CommunityCareConstants

      REFERRAL_DETAIL_VIEW_METRIC = "#{STATSD_PREFIX}.referral_detail.access".freeze
      REFERRAL_STATIONID_METRIC = "#{STATSD_PREFIX}.referral_station_id.access".freeze
      REFERRING_FACILITY_CODE_FIELD = 'referring_facility_code'
      REFERRAL_PROVIDER_NPI_FIELD = 'referral_provider_npi'

      # GET /v2/referrals
      # Fetches a list of referrals for the current user
      # Filters out expired referrals and adds encrypted UUIDs for security
      def index
        response = referral_service.get_vaos_referral_list(
          current_user.icn,
          referral_status_param
        )

        log_referral_count(response)

        # Filter out expired referrals
        response = filter_expired_referrals(response)
        # Add encrypted UUIDs to the referrals for URL usage
        add_referral_uuids(response)

        render json: Ccra::ReferralListSerializer.new(response)
      end

      # GET /v2/referrals/:uuid
      # Fetches a specific referral by its encrypted UUID
      # Decrypts the UUID to retrieve the referral consult ID
      def show
        decrypted_id = VAOS::ReferralEncryptionService.decrypt(referral_uuid)
        response = referral_service.get_referral(decrypted_id, current_user.icn)
        response.uuid = referral_uuid

        log_referral_metrics(response)
        add_appointment_data_to_referral(response)

        render json: Ccra::ReferralDetailSerializer.new(response)
      end

      private

      def add_appointment_data_to_referral(referral)
        result = appointments_service.get_active_appointments_for_referral(referral.referral_number)

        eps_appointments = result[:EPS][:data]
        vaos_appointments = result[:VAOS][:data]

        referral.appointments = {
          EPS: {
            data: eps_appointments.map { |appt| { id: appt[:id], status: appt[:status], start: appt[:start] } }
          },
          VAOS: {
            data: vaos_appointments.map { |appt| { id: appt[:id], status: appt[:status], start: appt[:start] } }
          }
        }

        # Only set has_appointments to true if there are appointments with status "active"
        eps_has_active = eps_appointments.any? { |appt| appt[:status] == 'active' }
        vaos_has_active = vaos_appointments.any? { |appt| appt[:status] == 'active' }
        referral.has_appointments = eps_has_active || vaos_has_active
      end

      def appointments_service
        @appointments_service ||= VAOS::V2::AppointmentsService.new(current_user)
      end

      # Logs the count of referrals returned from CCRA
      #
      # @param referrals [Array<Ccra::ReferralListEntry>] The collection of referrals
      # @return [void]
      def log_referral_count(referrals)
        count = referrals&.size || 0
        Rails.logger.info("CCRA referrals retrieved: #{count}", { referral_count: count }.to_json)
        StatsD.gauge('api.vaos.referrals.retrieved', count, tags: ["has_referrals:#{count.positive?}"])
      end

      # Adds encrypted UUIDs to referrals for use in URLs to prevent PII in logs
      #
      # @param referrals [Array<Ccra::ReferralListEntry>] The collection of referrals
      # @return [Array<Ccra::ReferralListEntry>] The modified collection
      def add_referral_uuids(referrals)
        return referrals unless referrals.respond_to?(:each)

        referrals.each do |referral|
          # Add encrypted UUID from the referral number
          referral.uuid = VAOS::ReferralEncryptionService.encrypt(referral.referral_consult_id)
        end
      end

      # The encrypted referral UUID from request parameters
      # @return [String] the referral UUID
      def referral_uuid
        params.require(:id)
      end

      # CCRA Referral Status Codes:
      # X  - Cancelled
      # BP - EOC Complete: Episode of Care is completed
      # AP - Approved: Referral approved/authorized for care
      # A  - First Appointment Made: Initial appointment scheduled
      # D  - Initial care
      # RJ - Referral Rejected
      # C  - Sent to Care Team
      # AC - Accepted: Referral accepted/authorized for care
      #
      # The referral status parameter for filtering referrals
      # @return [String] the referral status
      def referral_status_param
        # Default to only show referrals that a veteran can make appointments for.
        params.fetch(:status, "'AP', 'C'")
      end

      # Filters out referrals that have expired (expiration date before today)
      #
      # @param referrals [Array<Ccra::ReferralListEntry>] The collection of referrals
      # @return [Array<Ccra::ReferralListEntry>] Filtered collection without expired referrals
      def filter_expired_referrals(referrals)
        return [] if referrals.nil?
        raise ArgumentError, 'referrals must be an enumerable collection' unless referrals.respond_to?(:each)

        today = Date.current
        referrals.reject { |referral| referral.expiration_date.present? && referral.expiration_date < today }
      end

      # Memoized referral service instance
      # @return [Ccra::ReferralService] the referral service
      def referral_service
        @referral_service ||= Ccra::ReferralService.new(current_user)
      end

      # Sanitizes log values by removing spaces and providing fallback for nil/empty values
      # @param value [String, nil] the value to sanitize
      # @return [String] sanitized value or "no_value" if blank
      def sanitize_log_value(value)
        return 'no_value' if value.blank?

        value.to_s.gsub(/\s+/, '_')
      end

      # Logs referral provider metrics and errors for missing provider IDs
      # @param response [Ccra::ReferralDetail] the referral response object
      def log_referral_metrics(response)
        referring_facility_code = sanitize_log_value(response&.referring_facility_code)
        provider_npi = sanitize_log_value(response&.provider_npi)
        station_id = sanitize_log_value(response&.station_id)
        type_of_care = sanitize_log_value(response&.category_of_care)

        StatsD.increment(REFERRAL_DETAIL_VIEW_METRIC, tags: [
                           COMMUNITY_CARE_SERVICE_TAG,
                           "referring_facility_code:#{referring_facility_code}",
                           "station_id:#{station_id}",
                           "type_of_care:#{type_of_care}"
                         ])

        log_missing_provider_ids(referring_facility_code, provider_npi, station_id)
      end

      # Logs specific errors when provider IDs are missing using structured logging
      #
      # @param referring_facility_code [String] the sanitized referring facility code ('no_value' if originally blank)
      # @param provider_npi [String] the sanitized provider NPI ('no_value' if originally blank)
      # @param station_id [String] the sanitized station ID of the referral ('no_value' if originally blank)
      # @return [void]
      def log_missing_provider_ids(referring_facility_code, provider_npi, station_id)
        missing_fields = []
        missing_fields << REFERRING_FACILITY_CODE_FIELD if referring_facility_code == 'no_value'
        missing_fields << REFERRAL_PROVIDER_NPI_FIELD if provider_npi == 'no_value'

        return if missing_fields.empty?

        Rails.logger.error('Community Care Appointments: Referral detail view: Missing provider data', {
                             missing_data: missing_fields,
                             station_id:,
                             user_uuid: current_user.uuid
                           })
      end
    end
  end
end
