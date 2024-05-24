# frozen_string_literal: true

module VAOS
  module V2
    # Iterates through an appointment's list of practitioners. Uses practitioner npi identifier to request
    # practitioner information from upstream. Concatenates all found provder names into a comma separated string.
    # uses both the VAOS::V2::MobilePPMSService cache and a local cache. The local cache prevents the MobilePPMSService
    # from repeatedly re-requesting the same data if the upstream fails to provide it the first time.
    class AppointmentProviderName
      NPI_NOT_FOUND_MSG = "We're sorry, we can't display your provider's information right now."

      def initialize(user)
        @user = user
        @providers_cache = {}
      end

      def form_names_from_appointment_practitioners_list(practitioners_list)
        return nil if practitioners_list.blank?

        provider_names = []
        practitioners_list.each do |practitioner|
          id = find_practitioner_id(practitioner)
          next unless id

          name = get_name(id)
          provider_names << name if name
        end
        provider_names.compact.join(', ').presence
      end

      private

      def get_name(id)
        return @providers_cache[id] if @providers_cache.key?(id)

        name = fetch_provider(id)
        # cache even if it's nil to avoid duplicate requests
        @providers_cache[id] = name
        name
      end

      def find_practitioner_id(practitioner)
        practitioner[:identifier]&.each do |i|
          return i[:value] if i[:system].include? 'us-npi'
        end
        nil
      end

      def fetch_provider(provider_id)
        provider_data = mobile_ppms_service.get_provider_with_cache(provider_id)
        provider_data&.name&.strip&.presence
      rescue Common::Exceptions::BackendServiceException
        NPI_NOT_FOUND_MSG
      end

      def mobile_ppms_service
        VAOS::V2::MobilePPMSService.new(@user)
      end
    end
  end
end
