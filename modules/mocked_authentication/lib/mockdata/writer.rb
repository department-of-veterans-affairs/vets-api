# frozen_string_literal: true

module MockedAuthentication
  module Mockdata
    class Writer
      def self.save_credential(credential:, credential_type:)
        parsed_email = parse_email(credential.with_indifferent_access['email'])
        file_name = get_file_path_for_email(parsed_email, credential_type)
        File.write(file_name, generate_json_from_credential(credential))
      end

      class << self
        private

        def get_file_path_for_email(email, type)
          "#{Settings.sign_in.mock_credential_dir}/credentials/#{type}/#{email}"
        end

        def parse_email(email)
          email_without_hostname = get_email_without_hostname(email)
          get_text_without_symbols(email_without_hostname)
        end

        def get_email_without_hostname(email)
          email[/[^@]+/]
        end

        def get_text_without_symbols(text)
          text.gsub(/\W/, '')
        end

        def generate_json_from_credential(credential)
          JSON.pretty_generate(credential)
        end
      end
    end
  end
end
