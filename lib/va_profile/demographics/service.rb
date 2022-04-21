# frozen_string_literal: true

require 'common/client/concerns/monitoring'
require 'common/client/errors'
require 'va_profile/service'
require 'va_profile/stats'
require_relative 'configuration'
require_relative 'demographic_response'

module VAProfile
  module Demographics
    class Service < VAProfile::Service
      OID = '2.16.840.1.113883.4.349'
      include Common::Client::Concerns::Monitoring
      configuration VAProfile::Demographics::Configuration

      # Returns a response object containing the user's preferred name, and gender-identity
      #
      # @return [VAProfile::Demographics::DemographicResponse] Sample response:
      #   {
      #     "preferred_name" => "SAM",
      #     "gender_identity: => VAProfile::Models::GenderIdentity<code: "F", name: "Female">
      #   }
      #
      def get_demographics
        with_monitoring do
          return build_response(401, nil) unless identifier_present?

          response = perform(:get, identity_path)
          build_response(response&.status, response&.body)
        end
      rescue Common::Client::Errors::ClientError => e
        if e.status == 404
          log_exception_to_sentry(
            e,
            { csp_id_with_aaid: csp_id_with_aaid },
            { va_profile: :demographics_not_found },
            :warning
          )

          return build_response(404, nil)
        elsif e.status >= 400 && e.status < 500
          return build_response(e.status, nil)
        end

        handle_error(e)
      rescue => e
        handle_error(e)
      end

      # VA Profile demographic endpoints use the OID (Organizational Identifier), the CSP ID,
      # and the Assigning Authority ID to identify which person will be updated/retrieved.
      def identity_path
        "#{OID}/#{ERB::Util.url_encode(csp_id_with_aaid.to_s)}"
      end

      def build_response(status, body)
        DemographicResponse.from(
          status: status,
          body: body,
          id: @user.account_id,
          type: 'mvi_models_mvi_profiles',
          gender: @user.gender_mpi,
          birth_date: @user.birth_date_mpi
        )
      end

      private

      def identifier_present?
        @user&.idme_uuid.present? || @user&.logingov_uuid.present?
      end

      def csp_id_with_aaid
        "#{csp_id}#{aaid}"
      end

      # For now, only valid if CSP (credential service provider) is id.me or login.gov
      def csp_id
        return @user&.idme_uuid     if @user&.idme_uuid.present?
        return @user&.logingov_uuid if @user&.logingov_uuid.present?
      end

      def aaid
        return '^PN^200VIDM^USDVA' if @user&.idme_uuid.present?
        return '^PN^200VLGN^USDVA' if @user&.logingov_uuid.present?
      end
    end
  end
end
