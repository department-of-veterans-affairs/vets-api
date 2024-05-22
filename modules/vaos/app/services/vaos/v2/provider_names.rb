# frozen_string_literal: true

module VAOS
  module V2
    # iterates through a v2 appointment's practitioners list and attempts to find any names in the list.
    # if the list includes a provider id but no name, it attempts to fetch that name from the PPMS service.
    # it then aggregates all of those names into a comma separated name string and returns it.
    # this mirrors the web app behavior as best we understand it, which uses the provider name from the
    # index if possible and makes a PPMS request when the name is missing but an id is present.
    # it's unclear if there will ever be multiple providers on a single appointment,
    # but we've coded for the possibility
    class ProviderNames
      NPI_NOT_FOUND_MSG = "We're sorry, we can't display your provider's information right now."

      def initialize(user)
        @user = user
        @providers_cache = {}
      end

      def form_names_from_appointment_practitioners_list(practitioners_list)
        return nil if practitioners_list.blank?

        provider_names = []

        practitioners_list.each do |practitioner|
          name = find_provider_name(practitioner)
          provider_names << name if name
        end
        provider_names.compact.join(', ').presence
      end

      private

      def find_provider_name(practitioner)
        # web does not do this
        # name = find_practitioner_name_in_list(practitioner)
        # return name if name

        id = find_practitioner_id_in_list(practitioner)
        return nil unless id

        return @providers_cache[id] if @providers_cache.key?(id)

        provider_data = fetch_provider(id)
        name = provider_data&.name&.strip&.presence
        # cache even if it's nil to avoid duplicate requests
        @providers_cache[id] = name
        name
      end

      def find_practitioner_name_in_list(practitioner)
        first_name = practitioner.dig(:name, :given)&.join(' ')&.strip
        last_name = practitioner.dig(:name, :family)
        [first_name, last_name].compact.join(' ').presence
      end

      def find_practitioner_id_in_list(practitioner)
        practitioner[:identifier]&.each do |i|
          return i[:value] if i[:system].include? 'us-npi' # comment out the if to make mobile tests work
        end
        nil
      end

      def fetch_provider(provider_id)
        mobile_ppms_service.get_provider_with_cache(provider_id)
      rescue Common::Exceptions::BackendServiceException
        NPI_NOT_FOUND_MSG
      end

      def mobile_ppms_service
        VAOS::V2::MobilePPMSService.new(@user)
      end
    end
  end
end
