# frozen_string_literal: true

module SAML
  module ResponseBuilder
    IDMELOA1 = 'http://idmanagement.gov/ns/assurance/loa/1/vets'.freeze
    IDMELOA3 = 'http://idmanagement.gov/ns/assurance/loa/3/vets'.freeze

    def create_user_identity(authn_context: IDMELOA1, account_type: 'N/A', level_of_assurance: ['1'])
      saml = build_saml_response(authn_context: authn_context, account_type: account_type, level_of_assurance: level_of_assurance)
      saml_user = SAML::User.new(saml)
      user_identity = UserIdentity.new(saml_user.to_hash).save
      user_identity
    end

    def saml_response_from_attributes(authn_context, attributes)
      build_saml_response(authn_context: authn_context, attributes: attributes)
    end

    def build_saml_response(authn_context: IDMELOA1, account_type: 'N/A', level_of_assurance: ['1'], attributes: nil)
      decrypted_document_partial = REXML::Document.new(authn_context_xml_partial(authn_context))
      saml = saml_attributes(authn_context: authn_context, account_type: account_type, level_of_assurance: level_of_assurance)
      instance_double(OneLogin::RubySaml::Response, attributes: attributes || saml,
                                                    decrypted_document: decrypted_document_partial,
                                                    is_a?: true,
                                                    is_valid?: true)
    end

    def authn_context_xml_partial(authn_context)
      <<-XML
      <?xml version="1.0"?>
      <samlp:Response xmlns:samlp="urn:oasis:names:tc:SAML:2.0:protocol" xmlns:saml="urn:oasis:names:tc:SAML:2.0:assertion">
        <saml:Assertion>
          <saml:AuthnStatement>
            <saml:AuthnContext>
              <saml:AuthnContextClassRef>#{authn_context}</saml:AuthnContextClassRef>
            </saml:AuthnContext>
          </saml:AuthnStatement>
        </saml:Assertion>
      </samlp:Response>
      XML
    end

    # rubocop:disable Metrics/MethodLength
    def saml_attributes(authn_context: IDMELOA1, account_type: 'N/A', level_of_assurance: ['1'])
      case authn_context
      when 'myhealthevet'
        OneLogin::RubySaml::Attributes.new(
          'mhv_icn' => ['1012853550V207686'],
          'mhv_profile' => ["{\"accountType\":\"#{account_type}\"}"],
          'mhv_uuid' => ['12345748'],
          'email' => ['kam+tristanmhv@adhocteam.us'],
          'multifactor' => [false],
          'uuid' => ['0e1bb5723d7c4f0686f46ca4505642ad'],
          'level_of_assurance' => level_of_assurance
        )
      when 'dslogon'
        OneLogin::RubySaml::Attributes.new(
          'dslogon_status' => ['DEPENDENT'],
          'dslogon_assurance' => [account_type],
          'dslogon_gender' => ['M'],
          'dslogon_deceased' => ['false'],
          'dslogon_idauthn_context' => ['ssn'],
          'uuid' => ['0e1bb5723d7c4f0686f46ca4505642ad'],
          'dslogon_uuid' => ['1606997570'],
          'email' => ['kam+tristanmhv@adhocteam.us'],
          'multifactor' => ['true'],
          'level_of_assurance' => level_of_assurance,
          'dslogon_birth_date' => [],
          'dslogon_fname' => ['Tristan'],
          'dslogon_lname' => ['MHV'],
          'dslogon_mname' => [''],
          'dslogon_idvalue' => ['111223333']
        )
      when IDMELOA1, IDMELOA3, 'dslogon_loa2', 'dslogon_loa3', 'myhealthevet_loa3', 'myhealthevet_multifactor', 'dslogon_multifactor'
        OneLogin::RubySaml::Attributes.new(
          'uuid'               => ['0e1bb5723d7c4f0686f46ca4505642ad'],
          'email'              => ['kam+tristanmhv@adhocteam.us'],
          'fname'              => ['Tristan'],
          'lname'              => ['MHV'],
          'mname'              => [''],
          'social'             => ['111223333'],
          'gender'             => ['male'],
          'birth_date'         => ['1735-10-30'],
          'level_of_assurance' => (authn_context == 'loa1' ? ['1'] : ['3']),
          'multifactor'        => [true]
        )
      end
      # rubocop:enable Metrics/MethodLength
    end
  end
end
