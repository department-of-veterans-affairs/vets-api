module VAOS
  class EpsConfiguration
    # These need to go in a settings file if they aren't already and then pulled like
    # Settings.vaos.eps.login_url
    # Settings.vaos.eps.base_path
    # Settings.vaos.eps.grant_type
    # Settings.vaos.eps.scope
    # Settings.vaos.eps.client_assertion_type

    def self.login_url
      'https://login.wellhive.com/oauth2/default/v1/token'
    end

    def self.base_path
      'https://api.wellhive.com/care-navigation/v1/'
    end

    def self.grant_type
      'client_credentials'
    end

    def self.scope
      'care-nav'
    end

    def self.client_assertion_type
      'urn:ietf:params:oauth:client-assertion-type:jwt-bearer'
    end
  end
end