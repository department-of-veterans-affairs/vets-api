require 'sinatra/base'
require 'saml_idp/controller'
require 'saml_idp/logout_request_builder'

module MockSamlIdp
  class Idp < Sinatra::Base
    include SamlIdp::Controller

    BASE_URL = 'https://api.idmelabs.com/'

    get '/saml/metadata/provider' do
      build_configs
      content_type 'text/xml'
      SamlIdp.metadata.sign(SamlIdp.config.password)
      SamlIdp.metadata.signed
    end

    get '/saml/auth' do
      build_configs
      validate_saml_request
      encode_response(user)
    end

    get '/saml/logout' do
      build_configs
      if params[:SAMLRequest]
        validate_saml_request
        encode_response(user)
      else
        logout_request_builder.signed
      end
    end

    private

    def logout_request_builder
      session_index = SecureRandom.uuid
      SamlIdp::LogoutRequestBuilder.new(
        session_index,
        SamlIdp.config.base_saml_location,
        'foo/bar/logout',
        user.uid,
        OpenSSL::Digest::SHA256
      )
    end

    def build_configs
      SamlIdp.configure do |config|
        config.idp_cert_multi = {
          signing: {
            signing_cert: File.read("#{Rails.root}/spec/support/mock_saml_idp/certificates/mock_idp.crt"),
            signing_key: File.read("#{Rails.root}/spec/support/mock_saml_idp/certificates/mock_idp.key"),
            password: 'abracadabra'
          },
          encryption: {
            encryption_cert: File.read("#{Rails.root}/spec/support/mock_saml_idp/certificates/mock_idp.crt"),
            encryption_key: File.read("#{Rails.root}/spec/support/mock_saml_idp/certificates/mock_idp.key"),
            password: 'abracadabra'
          },
        }
        config.algorithm = :sha256
        config.organization_name = ''
        config.organization_url = BASE_URL
        config.base_saml_location = "#{BASE_URL}/saml"
        config.reference_id_generator = -> { UUID.generate }
        config.attribute_service_location = "#{BASE_URL}/saml/attributes"
        config.single_service_post_location = "#{BASE_URL}/saml/auth"
        config.single_logout_service_post_location = "#{BASE_URL}/saml/logout"

        config.name_id.formats = {
          persistent: -> (principal) { principal.uid },
          email_address: -> (principal) { principal.email }
        }

        config.service_provider.finder = lambda do |_issuer_or_entity_id|
          idp_cert = OpenSSL::x509::Certificate.new(config.x509_certificate).to_der
          {
            cert: idp_cert,
            fingerprint: OpenSSL::Digest::SHA1.hexdigest(idp_cert),
            private_key: config.secret_key,
            assertion_consumer_logout_service_url: 'http://www.example.com/auth/saml/logout'
          }
        end
      end
    end

    def user
      if saml_request && saml_request.name_id
        add_asserted_attributes User.find_by_uid(saml_request.name_id)
      else
        add_asserted_attributes User.new(email: 'fakeuser@example.com', uid: SecureRandom.uuid)
      end
    end

    def add_asserted_attributes(user)
      attrs = {
        uid: {
          getter: :uid,
          name_format: Saml::XML::Namespaces::Formats::NameId::PERSISTENT,
          name_id_format: Saml::XML::Namespaces::Formats::NameId::PERSISTENT
        },
        email: {
          getter: :email,
          name_format: Saml::XML::Namespaces::Formats::NameId::EMAIL_ADDRESS,
          name_id_format: Saml::XML::Namespaces::Formats::NameId::EMAIL_ADDRESS
        }
      }
      add_bundle(attrs) if authn_request_bundle
      user_waa = UserWithAssertedAttributes.new(user)
      user_waa.call attrs
      user_waa
    end

    def add_bundle(attrs)
      authn_request_bundle.each do |attr|
        attrs[attr] = { getter: attr }
      end
    end

    def authn_request_bundle
      return unless saml_request && authn_context_attr_nodes.any?
      authn_context_attr_nodes.
        join(':').
        gsub(ASSERTED_ATTRIBUTES_URI_PATTERN, '').
        split(/\W+/).
        compact.uniq.
        map(&:to_sym)
    end

    def authn_context_attr_nodes
      @_attr_node_contents ||= begin
        doc = Saml::XML::Document.parse(saml_request.raw_xml)
        doc.xpath(
          '//samlp:AuthnRequest/samlp:RequestedAuthnContext/saml:AuthnContextClassRef',
          samlp: Saml::XML::Namespaces::PROTOCOL,
          saml: Saml::XML::Namespaces::ASSERTION
        ).select do |node|
          node.content =~ /#{Regexp.escape(ASSERTED_ATTRIBUTES_URI_PATTERN)}/
        end
      end
    end
  end
end
