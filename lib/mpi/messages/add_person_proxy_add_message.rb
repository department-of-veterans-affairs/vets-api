# frozen_string_literal: true

require 'socket'
require 'formatters/date_formatter'

module MPI
  module Messages
    # Builds an MPI SOAP XML message for adding an external system for an existing user.
    #
    # Call with a user object and use `.to_xml` method to create the XML message
    #
    # Example:
    #  message = MPI::Messages::AddPersonProxyAddMessage.new(user).to_xml
    #
    class AddPersonProxyAddMessage
      SCHEMA_FILE_NAME = 'mpi_add_person_proxy_add_template.xml'

      def initialize(user)
        raise ArgumentError, 'User missing attributes' unless can_mvi_proxy_add?(user)

        @user = user
      end

      def to_xml
        template = Liquid::Template.parse(
          File.read(File.join('config', 'mpi_schema', SCHEMA_FILE_NAME))
        )

        template.render!(build_content(@user))
      end

      private

      def can_mvi_proxy_add?(user)
        personal_info?(user) &&
          user.edipi.present? &&
          user.icn_with_aaid.present? &&
          user.search_token.present?
      rescue # Default to false for any error
        false
      end

      def personal_info?(user)
        user.first_name.present? &&
          user.last_name.present? &&
          user.ssn.present? &&
          user.birth_date.present?
      end

      def build_content(user)
        current_time = Time.current
        # For BGS, they require a the clients ip address for the telecom value in the xml payload
        # This is to trace the request all the way from BGS back to vets-api if the need arises
        ip_address = Socket.ip_address_list.find { |ip| ip.ipv4? && !ip.ipv4_loopback? }.ip_address
        {
          'msg_id' => "200VGOV-#{SecureRandom.uuid}",
          'date_of_request' => current_time.strftime('%Y%m%d%H%M%S'),
          'processing_code' => Settings.mvi.processing_code,
          'search_token' => user.search_token,
          'user_identity' => user.icn_with_aaid,
          'edipi' => user.edipi,
          'first_name' => user.first_name,
          'last_name' => user.last_name,
          'date_of_birth' => Formatters::DateFormatter.format_date(user.birth_date, :number_iso8601),
          'ssn' => user.ssn,
          'current_datetime' => current_time.strftime('%Y-%m-%d %H:%M:%S'),
          'ip_address' => ip_address
        }
      end
    end
  end
end
