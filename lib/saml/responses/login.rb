# frozen_string_literal: true
require 'saml/responses/base'

module SAML
  module Responses
    class Login < OneLogin::RubySaml::Response
      include SAML::Responses::Base
    end
  end
end
