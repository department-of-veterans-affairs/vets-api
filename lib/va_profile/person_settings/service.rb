# frozen_string_literal: true

# Service layer for interacting with VAProfile Person Settings API. This service is still under
# development and not fully integrated, gated behind the profile_scheduling_preferences
# feature flag via the SchedulingPreferencesController.

require 'va_profile/contact_information/v2/transaction_response'
require 'va_profile/person_settings/configuration'
require 'va_profile/person_settings/person_options_response'

module VAProfile
  module PersonSettings
    class Service < VAProfile::Service
      include Common::Client::Concerns::Monitoring

      configuration VAProfile::PersonSettings::Configuration

      STATSD_KEY_PREFIX = "#{VAProfile::Service::STATSD_KEY_PREFIX}.person_settings".freeze
      VA_PROFILE_ID_POSTFIX = '^PI^200VETS^USDVA'
      ICN_POSTFIX = '^NI^200M^USVHA'

      # The API is set up to support multiple containers in future, but for now we are only
      # using the preferences container for the VA.gov scheduling preferences page
      CONTAINER_IDS = { preferences: 1 }.freeze

      # GET's a user's person options from the VAProfile API
      # @param container_ids [Integer, Array<Integer>, nil] optional container id(s) to filter results
      # @return [VAProfile::PersonSettings::PersonOptionsResponse] response wrapper around person options object
      def get_person_options(container_ids = nil)
        with_monitoring do
          verify_user!
          raw_response = perform(:get, person_options_request_path(container_ids))
          PersonOptionsResponse.from(raw_response)
        end
      rescue Common::Client::Errors::ClientError => e
        if e.status == 404
          Rails.logger.warn('User not found in VAProfile', vaprofile_id: @user&.vet360_id)
          return PersonOptionsResponse.new(404, person_options: [])
        elsif e.status.to_i >= 400 && e.status.to_i < 500
          return PersonOptionsResponse.new(e.status, person_options: [])
        end

        handle_error(e)
      rescue => e
        handle_error(e)
      end

      # POSTs updated person options to the VAProfile API
      # @param person_options_data [Hash] the person options data to be sent to VAProfile in JSON format
      # @return [VAProfile::ContactInformation::V2::PersonOptionsTransactionResponse] response wrapper around tx object
      def update_person_options(person_options_data)
        with_monitoring do
          verify_user!
          raw_response = perform(:post, person_options_request_path, person_options_data.to_json)
          VAProfile::ContactInformation::V2::PersonOptionsTransactionResponse.from(raw_response)
        end
      rescue => e
        handle_error(e)
      end

      private

      # Verify user identity and log results
      def verify_user!
        unless @user&.vet360_id.present? || @user&.icn.present?
          raise 'PersonSettings - Missing User ICN and VAProfile_ID'
        end

        Rails.logger.info(
          "PersonSettings User MVI Verified? : #{@user&.icn.present?}, VAProfile Verified? #{@user&.vet360_id.present?}"
        )
      end

      # Request path for person options endpoint formatted as person-options/v1/{oid}/{idWithAaid}
      # Optional container_ids param allows for filtering results on GET requests by formatting as query parameters
      def person_options_request_path(container_ids = nil)
        path = "person-options/v1/#{MPI::Constants::VA_ROOT_OID}/#{ERB::Util.url_encode(vaprofile_id_with_aaid)}"

        return path if container_ids.blank?

        ids = Array(container_ids)
        query_params = URI.encode_www_form(ids.map { |id| ['containerId', id] })

        "#{path}?#{query_params}"
      end

      # User ID with AAID for VAProfile Requests
      # Prefer VAProfile_ID if present, otherwise use ICN
      def vaprofile_id_with_aaid
        return "#{@user.vet360_id}#{VA_PROFILE_ID_POSTFIX}" if @user.vet360_id.present?

        "#{@user.icn}#{ICN_POSTFIX}"
      end
    end
  end
end
