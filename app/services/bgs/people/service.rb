# frozen_string_literal: true

module BGS
  module People
    class Service
      class VAFileNumberNotFound < StandardError; end

      include SentryLogging

      attr_reader :ssn,
                  :participant_id,
                  :common_name,
                  :email,
                  :icn

      def initialize(user)
        @ssn = user.ssn
        @participant_id = user.participant_id
        @common_name = user.common_name
        @email = user.email
        @icn = user.icn
      end

      def find_person_by_participant_id
        raw_response = service.people.find_person_by_ptcpnt_id(participant_id, ssn)
        if raw_response.blank?
          log_exception_to_sentry(VAFileNumberNotFound.new, { icn: }, { team: Constants::SENTRY_REPORTING_TEAM })
        end
        BGS::People::Response.new(raw_response, status: :ok)
      rescue => e
        log_exception_to_sentry(e, { icn: }, { team: Constants::SENTRY_REPORTING_TEAM })
        BGS::People::Response.new(nil, status: :error)
      end

      private

      def service
        @service ||= BGS::Services.new(external_uid: icn, external_key:)
      end

      def external_key
        @external_key ||= begin
          key = common_name.presence || email
          key.first(Constants::EXTERNAL_KEY_MAX_LENGTH)
        end
      end
    end
  end
end
