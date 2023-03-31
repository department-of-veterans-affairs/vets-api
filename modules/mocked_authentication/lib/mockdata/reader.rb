# frozen_string_literal: true

module MockedAuthentication
  module Mockdata
    class Reader
      LOGINGOV_FILEPATH = 'logingov'
      IDME_FILEPATH = 'idme'
      DSLOGON_FILEPATH = 'dslogon'
      MHV_FILEPATH = 'mhv'

      def self.find_credentials(credential_type:)
        file_names = get_file_names(credential_type)
        get_mocked_data(file_names)
      end

      class << self
        private

        def get_file_names(type)
          file_directory = get_file_directory_for_type(type)
          Dir.glob("#{file_directory}/*.json")
        end

        def get_file_directory_for_type(type)
          type = sanitize_type(type)
          "#{Settings.sign_in.mock_credential_dir}/credentials/#{type}"
        end

        def sanitize_type(type)
          case type
          when SignIn::Constants::Auth::IDME
            IDME_FILEPATH
          when SignIn::Constants::Auth::LOGINGOV
            LOGINGOV_FILEPATH
          when SignIn::Constants::Auth::DSLOGON
            DSLOGON_FILEPATH
          when SignIn::Constants::Auth::MHV
            MHV_FILEPATH
          end
        end

        def get_mocked_data(file_names)
          mocked_data = {}
          file_names.each { |f| update_mocked_data(mocked_data, f) }

          mocked_data
        end

        def update_mocked_data(mocked_data, file_name)
          read_file = File.read(file_name)
          user_identifier = File.basename(file_name, '.json')
          credential_data = JSON.parse(read_file)

          mocked_data[user_identifier] = {
            encoded_credential: Base64.encode64(read_file),
            credential_payload: credential_data
          }
        end
      end
    end
  end
end
