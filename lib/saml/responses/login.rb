# frozen_string_literal: true

require 'saml/responses/base'

module SAML
  module Responses
    class Login < OneLogin::RubySaml::Response
      include SAML::Responses::Base

      def initialize(saml_response, options={})
        begin
          super(saml_response, options)
        rescue OpenSSL::PKey::RSAError => e
          raise e unless Settings.saml.key_new

          duped_options = options.dup
          duped_options[:settings].private_key = Settings.saml.key_new
          super(saml_response, duped_options)
        end
      end

      def errors_message
        @errors_message ||= if errors.any?
                              message = 'Login Failed! '
                              message += errors_hash[:short_message]
                              message += ' Multiple SAML Errors' if normalized_errors.count > 1
                              message
                            end
      end
    end
  end
end
