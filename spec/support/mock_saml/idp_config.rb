module MockSaml
  class Config
    BASE_URL = 'https://api.idmelabs.com'
    ORG_NAME = 'ID.me'
    ORG_URL  = 'https://www.id.me'

    def initialize
      SamlIdp.configure do |config|
        config.idp_cert_multi = idp_cert_multi
        config.algorithm = :sha256
        config.organization_name = ORG_NAME
        config.organization_url = ORG_URL
        config.base_saml_location = "#{BASE_URL}/saml"
        config.artifact_resolution_service_location = "#{BASE_URL}/saml/ArtifactResolutionService"
        config.single_logout_service_post_location = "#{BASE_URL}/saml/SingleLogoutService"
        config.single_logout_service_redirect_location = "#{BASE_URL}/saml/SingleLogoutService"
        config.single_sign_on_service_post_location = "#{BASE_URL}/saml/SingleSignOnService"
        config.single_sign_on_service_redirect_location = "#{BASE_URL}/saml/SingleSignOnService"

        config.reference_id_generator = -> { UUID.generate }
        config.entity_attributes = entity_attributes
        config.attributes = user_attributes
        config.name_id.formats = name_id_formats

        sp_cert = OpenSSL::X509::Certificate.new(File.read(Settings.saml.cert_path))
        sp_cert_fingerprint = OpenSSL::Digest::SHA1.hexdigest(sp_cert.to_der).scan(/../).join(':')
        service_providers = {
          'localhost:3000/saml' => {
            cert: sp_cert,
            fingerprint: sp_cert_fingerprint,
            metadata_url: 'http://localhost:3000/saml/metadata',
            acs_url: 'http://localhost:3000/saml/auth/callback/',
            assertion_consumer_logout_service_url: 'http://localhost:3000/saml/auth/logout/',
          }
        }

        config.service_provider.finder = lambda do |issuer_or_entity_id|
          service_providers[issuer_or_entity_id]
        end
      end
    end

    private

    def idp_cert_multi
      {
        signing: {
          signing_cert: File.read("spec/support/certificates/idp_multi_signing_cert.crt"),
          signing_key: File.read("spec/support/certificates/idp_multi_signing_key.key"),
          password: '1234'
        },
        encryption: {
          encryption_cert: File.read("spec/support/certificates/idp_multi_encryption_cert.crt"),
          encryption_key: File.read("spec/support/certificates/idp_multi_encryption_key.key"),
          password: '1234'
        }
      }
    end

    def entity_attributes
      [{
        name: "urn:oasis:names:tc:SAML:attribute:assurance-certification",
        name_format: "urn:oasis:names:tc:SAML:2.0:attrname-format:basic",
        values_array: [
          "http://idmanagement.gov/ns/assurance/loa/1",
          "http://idmanagement.gov/ns/assurance/loa/2",
          "http://idmanagement.gov/ns/assurance/loa/3"
        ]
      }]
    end

    def user_attributes
      {
        "Birth Date" => {
          name: "birth_date",
          name_format: "urn:oasis:names:tc:SAML:2.0:attrname-format:basic",
          friendly_name: "Birth Date"
        },
        "City" => {
          name: "city",
          name_format: "urn:oasis:names:tc:SAML:2.0:attrname-format:basic",
          friendly_name: "City"
        },
        "Country" => {
          name: "country",
          name_format: "urn:oasis:names:tc:SAML:2.0:attrname-format:basic",
          friendly_name: "Country"
        },
        "Email" => {
          name: "email",
          name_format: "urn:oasis:names:tc:SAML:2.0:attrname-format:basic",
          friendly_name: "Email"
        },
        "First Name" => {
          name: "fname",
          name_format: "urn:oasis:names:tc:SAML:2.0:attrname-format:basic",
          friendly_name: "First Name"
        },
        "Full Name" => {
          name: "full_name",
          name_format: "urn:oasis:names:tc:SAML:2.0:attrname-format:basic",
          friendly_name: "Full Name"
        },
        "Full SSN" => {
          name: "social",
          name_format: "urn:oasis:names:tc:SAML:2.0:attrname-format:basic",
          friendly_name: "Full SSN"
        },
        "Gender" => {
          name: "gender",
          name_format: "urn:oasis:names:tc:SAML:2.0:attrname-format:basic",
          friendly_name: "Gender"
        },
        "Last 4 of SSN" => {
          name: "social_short",
          name_format: "urn:oasis:names:tc:SAML:2.0:attrname-format:basic",
          friendly_name: "Last 4 of SSN"
        },
        "Last Name" => {
          name: "lname",
          name_format: "urn:oasis:names:tc:SAML:2.0:attrname-format:basic",
          friendly_name: "Last Name"
        },
        "Middle Name" => {
          name: "mname",
          name_format: "urn:oasis:names:tc:SAML:2.0:attrname-format:basic",
          friendly_name: "Middle Name"
        },
        "Phone" => {
          name: "phone",
          name_format: "urn:oasis:names:tc:SAML:2.0:attrname-format:basic",
          friendly_name: "Phone"
        },
        "Postal Code" => {
          name: "zip",
          name_format: "urn:oasis:names:tc:SAML:2.0:attrname-format:basic",
          friendly_name: "Postal Code"
        },
        "State" => {
          name: "state",
          name_format: "urn:oasis:names:tc:SAML:2.0:attrname-format:basic",
          friendly_name: "State"
        },
        "Street" => {
          name: "street",
          name_format: "urn:oasis:names:tc:SAML:2.0:attrname-format:basic",
          friendly_name: "Street"
        },
        "Suffix" => {
          name: "suffix",
          name_format: "urn:oasis:names:tc:SAML:2.0:attrname-format:basic",
          friendly_name: "Suffix"
        },
        "Verified credentials" => {
          name: "credentials",
          name_format: "urn:oasis:names:tc:SAML:2.0:attrname-format:basic",
          friendly_name: "Verified credentials"
        }
      }
    end

    def name_id_formats
      {
        "1.1" => {
          unspecified: -> (principal) { principal.birth_date }
        },
        "2.0" => {
          persistent: -> (principal) { principal.birth_date },
          transient: -> (principal) { principal.birth_date }
        }
      }
    end
  end
end
