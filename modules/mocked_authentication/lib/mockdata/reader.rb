# frozen_string_literal: true

module MockedAuthentication
  module Mockdata
    class Reader
      LOGINGOV_CREDENTIAL_FILEPATH = 'logingov'
      IDME_CREDENTIAL_FILEPATH = 'idme'
      MHV_CREDENTIAL_FILEPATH = 'mhv'

      IDME_MPI_FILEPATH = 'profile_idme_uuid'
      LOGINGOV_MPI_FILEPATH = 'profile_logingov_uuid'

      def self.find_credentials(credential_type:)
        credential_file_names = get_credential_file_names_for_type(credential_type)
        mpi_directory = get_mpi_file_directory_for_type(credential_type)
        get_mocked_credential_data(credential_file_names, mpi_directory)
      end

      class << self
        private

        def get_credential_file_names_for_type(type)
          credential_file_directory = get_credential_file_directory_for_type(type)
          Dir.glob("#{credential_file_directory}/*.json")
        end

        def get_credential_file_directory_for_type(type)
          credential_directory = convert_type_to_credential_directory(type)
          "#{Settings.betamocks.cache_dir}/credentials/#{credential_directory}"
        end

        def get_mpi_file_directory_for_type(type)
          mpi_directory = convert_type_to_mpi_directory(type)
          "#{Settings.betamocks.cache_dir}/mvi/#{mpi_directory}"
        end

        def convert_type_to_credential_directory(type)
          case type
          when SignIn::Constants::Auth::IDME
            IDME_CREDENTIAL_FILEPATH
          when SignIn::Constants::Auth::LOGINGOV
            LOGINGOV_CREDENTIAL_FILEPATH
          when SignIn::Constants::Auth::MHV
            MHV_CREDENTIAL_FILEPATH
          end
        end

        def convert_type_to_mpi_directory(type)
          case type
          when SignIn::Constants::Auth::IDME, SignIn::Constants::Auth::MHV
            IDME_MPI_FILEPATH
          when SignIn::Constants::Auth::LOGINGOV
            LOGINGOV_MPI_FILEPATH
          end
        end

        def get_mocked_credential_data(credential_file_names, mpi_directory)
          mocked_credential_data = {}
          credential_file_names.each do |credential_file_name|
            credential_user_identifier = File.basename(credential_file_name, '.json')
            mocked_credential_data[credential_user_identifier] =
              update_mocked_credential_data(credential_file_name, mpi_directory)
          end

          mocked_credential_data
        end

        def update_mocked_credential_data(credential_file_name, mpi_directory)
          credential_file = File.read(credential_file_name)
          encoded_credential_file = Base64.encode64(credential_file)
          credential_data = JSON.parse(credential_file)
          mpi_file = "#{mpi_directory}/#{credential_data['sub']}.yml"

          {
            encoded_credential: encoded_credential_file,
            credential_payload: credential_data,
            mpi_mock_exists: File.exist?(mpi_file)
          }
        end
      end
    end
  end
end
