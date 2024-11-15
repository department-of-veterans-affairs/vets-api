# frozen_string_literal: true

module EPS
  class Configuration < Common::Client::Configuration::REST
    def self.login_url
      Settings.vaos.eps.access_token_url
    end

    def self.base_path
      Settings.vaos.eps.api_url
    end

    def self.grant_type
      Settings.vaos.eps.grant_type
    end

    def self.scope
      Settings.vaos.eps.scopes
    end

    def self.client_assertion_type
      Settings.vaos.eps.client_assertion_type
    end
  end
end
