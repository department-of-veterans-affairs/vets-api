require 'support/mock_saml/idp_config'
require 'saml_idp/controller'
require 'saml_idp/logout_request_builder'

module MockSaml
  class IdpService
    include SamlIdp::Controller

    def initialize
      MockSaml::Config.new
    end

    def metadata
      SamlIdp.metadata.sign(SamlIdp.config.password)
      SamlIdp.metadata.signed
    end

    def sso_saml_response(user = FactoryBot.build(:saml_idme_user))
      # we're not dealing with actual params at the service level so no need to validate
      # validate_saml_request
      encode_response(user, service_provider_options)
    end

    def slo_saml_response(user = FactoryBot.build(:saml_idme_user))
    end

    private

    def service_provider_options
      {
        audience_uri: 'http://localhost:3000/saml/auth/callback/',
        issuer_uri: 'localhost:3000/saml',
        authn_context_classref: 'something_authn_context',
        acs_url: 'http://localhost:3000/saml/auth/callback/',
        encryption: {
          cert: encryption_cert,
          block_encryption: 'aes256-cbc',
          key_transport: 'rsa-oaep-mgf1p'
        }
      }
    end

    def encryption_cert
      File.read(Settings.saml.cert_path)
    end
  end
end
