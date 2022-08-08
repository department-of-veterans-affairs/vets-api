# frozen_string_literal: true

require 'socket'
require 'formatters/date_formatter'

module MPI
  module Messages
    class UpdateProfileMessage
      SCHEMA_FILE_NAME = 'mpi_update_profile_template.xml'

      attr_reader :first_name, :last_name, :ssn, :birth_date, :idme_uuid, :logingov_uuid, :icn, :edipi

      # rubocop:disable Metrics/ParameterLists
      def initialize(first_name:,
                     last_name:,
                     ssn:,
                     icn:,
                     birth_date:,
                     idme_uuid: nil,
                     logingov_uuid: nil,
                     edipi: nil)

        @first_name = first_name
        @last_name = last_name
        @ssn = ssn
        @icn = icn
        @birth_date = birth_date
        @idme_uuid = idme_uuid
        @logingov_uuid = logingov_uuid
        @edipi = edipi

        validate_attributes
      end
      # rubocop:enable Metrics/ParameterLists

      def to_xml
        template = Liquid::Template.parse(
          File.read(File.join('config', 'mpi_schema', SCHEMA_FILE_NAME))
        )

        template.render!(build_content)
      end

      private

      def validate_attributes
        unless first_name.present? &&
               last_name.present? &&
               ssn.present? &&
               birth_date.present? &&
               icn.present? &&
               (logingov_uuid.present? || edipi.present? || idme_uuid.present?)
          raise Errors::ArgumentError, 'Update Profile Missing Attributes'
        end
      end

      def build_content
        current_time = Time.current
        {
          'msg_id' => "200VGOV-#{SecureRandom.uuid}",
          'date_of_request' => current_time.strftime('%Y%m%d%H%M%S'),
          'processing_code' => Settings.mvi.processing_code,
          'first_name' => first_name,
          'last_name' => last_name,
          'user_identity' => icn_with_aaid,
          'date_of_birth' => Formatters::DateFormatter.format_date(birth_date, :number_iso8601),
          'ssn' => ssn,
          'csp_uuid' => csp_uuid,
          'csp_identifier' => csp_identifier,
          'identifier_root' => identifier_root
        }
      end

      def icn_with_aaid
        "#{icn}^NI^200M^USVHA^P"
      end

      def csp_identifier
        if edipi
          Constants::DSLOGON_FULL_IDENTIFIER
        elsif logingov_uuid
          Constants::LOGINGOV_FULL_IDENTIFIER
        else
          Constants::IDME_FULL_IDENTIFIER
        end
      end

      def csp_uuid
        edipi || logingov_uuid || idme_uuid
      end

      def identifier_root
        if edipi
          '2.16.840.1.113883.3.42.10001.100001.12'
        else
          '2.16.840.1.113883.4.349'
        end
      end
    end
  end
end
