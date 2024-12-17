# frozen_string_literal: true

module VAOS
  module V2
    # Finds the first provider npi id found in provider list and uses that id to request provider name.
    class AppointmentProviderName
      NPI_NOT_FOUND_MSG = "We're sorry, we can't display your provider's information right now."

      def initialize(user)
        @user = user
        @providers_cache = {}
      end

      def form_names_from_appointment_practitioners_list(practitioners_list)
        return nil if practitioners_list.blank?

        practitioners_list.each do |practitioner|
          id = find_practitioner_id(practitioner)
          next unless id

          name = get_name(id)
          return name if name
        end
        nil
      end

      private

      # uses a local cache on top of the ppms provider cache to avoid duplicate requests if upstream fails
      def get_name(id)
        return @providers_cache[id] if @providers_cache.key?(id)

        name = fetch_provider(id)
        @providers_cache[id] = name
        name
      end

      def find_practitioner_id(practitioner)
        practitioner[:identifier]&.each do |i|
          return i[:value]&.tr('^0-9', '') if i[:system].include? 'us-npi'
        end
        nil
      end

      def fetch_provider(provider_id)
        provider_data = mobile_ppms_service.get_provider_with_cache(provider_id)
        provider_data&.name&.strip&.presence
      rescue Common::Exceptions::BackendServiceException
        NPI_NOT_FOUND_MSG
      rescue URI::InvalidURIError
        nil
      end

      def mobile_ppms_service
        VAOS::V2::MobilePPMSService.new(@user)
      end
    end
  end
end
