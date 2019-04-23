# frozen_string_literal: true

require 'saml/responses/base'

module SAML
  module Responses
    class Logout < OneLogin::RubySaml::Logoutresponse
      include SAML::Responses::Base

      def errors_message
        @errors_message ||= if errors.any?
                              message = 'Logout Failed! '
                              message += errors_hash[:short_message]
                              message += ' Multiple SAML Errors' if normalized_errors.count > 1
                              message
                            end
      end
    end
  end
end
