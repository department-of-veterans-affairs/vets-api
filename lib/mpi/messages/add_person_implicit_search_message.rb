# frozen_string_literal: true

require 'socket'
require 'formatters/date_formatter'

module MPI
  module Messages
    class AddPersonImplicitSearchMessage
      SCHEMA_FILE_NAME = 'mpi_add_person_implicit_search_template.xml'

      attr_reader :first_name, :last_name, :ssn, :birth_date, :idme_uuid, :logingov_uuid

      # rubocop:disable Metrics/ParameterLists
      def initialize(first_name:,
                     last_name:,
                     ssn:,
                     birth_date:,
                     idme_uuid: nil,
                     logingov_uuid: nil)

        @first_name = first_name
        @last_name = last_name
        @ssn = ssn
        @birth_date = birth_date
        @idme_uuid = idme_uuid
        @logingov_uuid = logingov_uuid

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
               (idme_uuid.present? || logingov_uuid.present?)
          raise Errors::ArgumentError, 'Add Person Implicit Search Missing Attributes'
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
          'date_of_birth' => Formatters::DateFormatter.format_date(birth_date, :number_iso8601),
          'ssn' => ssn,
          'csp_uuid' => csp_uuid,
          'csp_identifier' => csp_identifier
        }
      end

      def csp_identifier
        if idme_uuid
          Constants::IDME_IDENTIFIER
        else
          Constants::LOGINGOV_IDENTIFIER
        end
      end

      def csp_uuid
        idme_uuid || logingov_uuid
      end
    end
  end
end
