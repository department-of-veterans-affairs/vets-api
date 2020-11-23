# frozen_string_literal: true

require 'socket'

module MPI
  module Messages
    # Builds an MPI SOAP XML message for adding a user.
    #
    # Call with a user object and use `.to_xml` method to create the XML message
    #
    # Example:
    #  message = MPI::Messages::AddPersonMessage.new(user).to_xml
    #
    class AddPersonMessage
      SCHEMA_FILE_NAME = 'mpi_add_person_template.xml'

      def initialize(user)
        raise ArgumentError, 'User missing attributes' unless user.can_mvi_proxy_add?

        @user = user
      end

      def to_xml
        template = Liquid::Template.parse(
          File.read(File.join('config', 'mpi_schema', SCHEMA_FILE_NAME))
        )

        template.render!(build_content(@user))
      end

      private

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
          'date_of_birth' => Date.parse(user.birth_date).strftime('%Y%m%d'),
          'ssn' => user.ssn,
          'current_datetime' => current_time.strftime('%Y-%m-%d %H:%M:%S'),
          'ip_address' => ip_address
        }
      end
    end
  end
end
