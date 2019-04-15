# frozen_string_literal: true
require 'saml/responses/base'

module SAML
  module Responses
    class Logout < OneLogin::RubySaml::Logoutresponse
      include SAML::Responses::Base
    end
  end
end
