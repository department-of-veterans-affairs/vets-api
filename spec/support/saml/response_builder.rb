# frozen_string_literal: true

module SAML
  # rubocop:disable Metrics/MethodLength, Metrics/ModuleLength
  module ResponseBuilder
    MHV_PREMIUM_ATYPE = [
      '{"accountType":"Premium","availableServices":{"21":"VA Medications","4":"Secure Messaging","3":"VA Allergies"'\
      ',"2":"Rx Refill","12":"Blue Button (all VA data)","1":"Blue Button self entered data.","11":"Blue Button (DoD)'\
      ' Military Service Information"}}'
    ].freeze

    def create_user_identity(authn_context:, account_type:, level_of_assurance:, multifactor:)
      saml = build_saml_response(
        authn_context: authn_context,
        account_type: account_type,
        level_of_assurance: level_of_assurance,
        multifactor: multifactor
      )
      saml_user = SAML::User.new(saml)
      user = create(:user, :response_builder, saml_user.to_hash)
      user.identity
    end

    def saml_response_from_attributes(authn_context, attributes)
      build_saml_response(authn_context: authn_context, attributes: attributes)
    end

    def build_saml_response_with_existing_user_identity?
      true
    end

    # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    def build_saml_response(authn_context:, account_type:, level_of_assurance:, multifactor:, attributes: nil)
      verifying = [LOA::IDME_LOA3, 'myhealthevet_loa3', 'dslogon_loa3'].include?(authn_context)

      if authn_context.present?
        if authn_context.include?('multifactor') && build_saml_response_with_existing_user_identity?
          previous_context = authn_context.gsub(/multifactor|_multifactor/, '').presence || LOA::IDME_LOA1
          create_user_identity(
            authn_context: previous_context,
            account_type: account_type,
            level_of_assurance: level_of_assurance,
            multifactor: [false]
          )
        end

        if verifying && build_saml_response_with_existing_user_identity?
          previous_context = authn_context.gsub(/_loa3/, '').gsub(%r{\/3\/}, '/1/')
          create_user_identity(
            authn_context: previous_context,
            account_type: account_type,
            level_of_assurance: '1',
            multifactor: multifactor
          )
        end
      end

      attributes ||= build_saml_attributes(
        authn_context: authn_context,
        account_type: account_type,
        level_of_assurance: verifying ? ['3'] : level_of_assurance,
        multifactor: multifactor
      )
      saml_response = SAML::Responses::Login.new(document_partial(authn_context).to_s)
      allow(saml_response).to receive(:attributes).and_return(attributes)
      allow(saml_response).to receive(:validate).and_return(true)
      allow(saml_response).to receive(:decrypted_document).and_return(document_partial(authn_context))
      saml_response
    end
    # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

    def build_invalid_saml_response(in_response_to:, decrypted_document:, errors:, status_message:)
      saml_response = SAML::Responses::Login.new(decrypted_document.to_s)
      allow(saml_response).to receive(:validate).and_return(false)
      allow(saml_response).to receive(:errors).and_return(errors)
      allow(saml_response).to receive(:in_response_to).and_return(in_response_to)
      allow(saml_response).to receive(:decrypted_document).and_return(decrypted_document)
      allow(saml_response).to receive(:status_message).and_return(status_message)
      saml_response
    end

    def invalid_saml_response
      build_invalid_saml_response(in_response_to: uuid,
                                  decrypted_document: document_partial)
    end

    def saml_response_click_deny
      build_invalid_saml_response(
        in_response_to: uuid,
        decrypted_document: nil,
        errors: ['The status code of the Response was not Success, was Responder => AuthnFailed '\
                 '-> Subject did not consent to attribute release',
                 'SAML Response must contain 1 assertion',
                 'The Assertion must include one Conditions element',
                 'The Assertion must include one AuthnStatement element',
                 'Issuer of the Assertion not found or multiple.',
                 'A valid SubjectConfirmation was not found on this Response'],
        status_message: 'Subject did not consent to attribute release'
      )
    end

    def saml_response_too_late
      build_invalid_saml_response(
        status_message: nil,
        in_response_to: uuid,
        decrypted_document: document_partial,
        errors: [
          'Current time is on or after NotOnOrAfter condition (2017-02-10 17:03:40 UTC >= 2017-02-10 17:03:30 UTC)',
          'A valid SubjectConfirmation was not found on this Response'
        ]
      )
    end

    def saml_response_too_early
      build_invalid_saml_response(
        status_message: nil,
        in_response_to: uuid,
        decrypted_document: document_partial,
        errors: [
          'Current time is earlier than NotBefore condition (2017-02-10 17:03:30 UTC) < 2017-02-10 17:03:40 UTC)'
        ]
      )
    end

    def saml_response_unknown_error
      build_invalid_saml_response(
        status_message: 'Default generic identity provider error',
        in_response_to: uuid,
        decrypted_document: document_partial,
        errors: [
          'The status code of the Response was not Success, was Requester => NoAuthnContext -> AuthnRequest without ' \
          'an authentication context.'
        ]
      )
    end

    def saml_response_multi_error
      build_invalid_saml_response(
        status_message: 'Subject did not consent to attribute release',
        in_response_to: uuid,
        decrypted_document: document_partial,
        errors: ['Subject did not consent to attribute release', 'Other random error']
      )
    end

    def document_partial(authn_context = '')
      REXML::Document.new(
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
      )
    end

    # TODO: Verify that attributes are available, in particular level_of_assurance and multifactor
    # TODO: fill out method for building SSOe saml atributes
    # TODO: validate attribute names for level of assurance and
    # multifactor after VA IAM integrates into response
    def build_ssoe_saml_attributes(authn_context:, account_type:, level_of_assurance:, multifactor:)
      if account_type == '1'
        OneLogin::RubySaml::Attributes.new(
          'va_eauth_credentialassurancelevel' => ['1'],
          'va_eauth_gender' => [],
          'va_eauth_uid' => ['0e1bb5723d7c4f0686f46ca4505642ad'],
          'va_eauth_dodedipnid' => ['1606997570'],
          'va_eauth_emailaddress' => ['kam+tristanmhv@adhocteam.us'],
          'multifactor' => (authn_context.include?('multifactor') ? [true] : multifactor),
          'level_of_assurance' => level_of_assurance,
          'va_eauth_birthDate_v1' => [],
          'va_eauth_firstname' => [],
          'va_eauth_lastname' => [],
          'va_eauth_middlename' => [],
          'va_eauth_pnid' => [],
          'va_eauth_postalcode' => [],
          'va_eauth_icn' => [],
          'va_eauth_mhvien' => []
        )
      else
        OneLogin::RubySaml::Attributes.new(
          'va_eauth_credentialassurancelevel' => [account_type],
          'va_eauth_gender' => ['M'],
          'va_eauth_uid' => ['0e1bb5723d7c4f0686f46ca4505642ad'],
          'va_eauth_dodedipnid' => ['1606997570'],
          'va_eauth_emailaddress' => ['kam+tristanmhv@adhocteam.us'],
          'multifactor' => (authn_context.include?('multifactor') ? [true] : multifactor),
          'level_of_assurance' => level_of_assurance,
          'va_eauth_birthDate_v1' => ['1735-10-30'],
          'va_eauth_firstname' => ['Tristan'],
          'va_eauth_lastname' => ['MHV'],
          'va_eauth_middlename' => [''],
          'va_eauth_pnid' => ['111223333'],
          'va_eauth_pnidtype' => ['SSN'],
          'va_eauth_postalcode' => ['12345'],
          'va_eauth_icn' => ['0000'],
          'va_eauth_mhvien' => ['0000']
        )
      end
    end

    def build_mhv_saml_attributes(authn_context:, account_type:, level_of_assurance:, multifactor:)
      OneLogin::RubySaml::Attributes.new(
        'mhv_icn' => (account_type == 'Basic' ? [''] : ['1012853550V207686']),
        'mhv_profile' => (account_type != 'Premium' ? ["{\"accountType\":\"#{account_type}\"}"] : MHV_PREMIUM_ATYPE),
        'mhv_uuid' => ['12345748'],
        'email' => ['kam+tristanmhv@adhocteam.us'],
        'multifactor' => (authn_context.include?('multifactor') ? [true] : multifactor),
        'uuid' => ['0e1bb5723d7c4f0686f46ca4505642ad'],
        'level_of_assurance' => level_of_assurance
      )
    end

    def build_dslogon_saml_attributes(authn_context:, account_type:, level_of_assurance:, multifactor:)
      if account_type == '1'
        OneLogin::RubySaml::Attributes.new(
          'dslogon_status' => [],
          'dslogon_assurance' => ['1'],
          'dslogon_gender' => [],
          'dslogon_deceased' => [],
          'dslogon_idtype' => [],
          'uuid' => ['0e1bb5723d7c4f0686f46ca4505642ad'],
          'dslogon_uuid' => ['1606997570'],
          'email' => ['kam+tristanmhv@adhocteam.us'],
          'multifactor' => (authn_context.include?('multifactor') ? [true] : multifactor),
          'level_of_assurance' => level_of_assurance,
          'dslogon_birth_date' => [],
          'dslogon_fname' => [],
          'dslogon_lname' => [],
          'dslogon_mname' => [],
          'dslogon_idvalue' => []
        )
      else
        OneLogin::RubySaml::Attributes.new(
          'dslogon_status' => ['DEPENDENT'],
          'dslogon_assurance' => [account_type],
          'dslogon_gender' => ['M'],
          'dslogon_deceased' => ['false'],
          'dslogon_idtype' => ['ssn'],
          'uuid' => ['0e1bb5723d7c4f0686f46ca4505642ad'],
          'dslogon_uuid' => ['1606997570'],
          'email' => ['kam+tristanmhv@adhocteam.us'],
          'multifactor' => (authn_context.include?('multifactor') ? [true] : multifactor),
          'level_of_assurance' => level_of_assurance,
          'dslogon_birth_date' => ['1735-10-30'],
          'dslogon_fname' => ['Tristan'],
          'dslogon_lname' => ['MHV'],
          'dslogon_mname' => [''],
          'dslogon_idvalue' => ['111223333']
        )
      end
    end

    # rubocop:disable Metrics/CyclomaticComplexity
    def build_saml_attributes(authn_context:, account_type:, level_of_assurance:, multifactor:)
      case authn_context
      when 'myhealthevet', 'myhealthevet_multifactor'
        build_mhv_saml_attributes(
          authn_context: authn_context,
          account_type: account_type,
          level_of_assurance: level_of_assurance,
          multifactor: multifactor
        )
      when 'dslogon', 'dslogon_multifactor'
        build_dslogon_saml_attributes(
          authn_context: authn_context,
          account_type: account_type,
          level_of_assurance: level_of_assurance,
          multifactor: multifactor
        )
      when LOA::IDME_LOA3, 'dslogon_loa3', 'myhealthevet_loa3'
        OneLogin::RubySaml::Attributes.new(
          'uuid'               => ['0e1bb5723d7c4f0686f46ca4505642ad'],
          'email'              => ['kam+tristanmhv@adhocteam.us'],
          'fname'              => ['Tristan'],
          'lname'              => ['MHV'],
          'mname'              => [''],
          'social'             => ['111223333'],
          'gender'             => ['male'],
          'birth_date'         => ['1735-10-30'],
          'level_of_assurance' => ['3'],
          'multifactor'        => [true] # always true for these types
        )
      when LOA::IDME_LOA1, 'multifactor'
        OneLogin::RubySaml::Attributes.new(
          'uuid'               => ['0e1bb5723d7c4f0686f46ca4505642ad'],
          'email'              => ['kam+tristanmhv@adhocteam.us'],
          'multifactor'        => (authn_context.include?('multifactor') ? [true] : multifactor),
          'level_of_assurance' => level_of_assurance
        )
      when 'ssoe'
        build_ssoe_saml_attributes(
          authn_context: authn_context,
          account_type: account_type,
          level_of_assurance: level_of_assurance,
          multifactor: multifactor
        )
      end
    end
  end
  # rubocop:enable Metrics/MethodLength, Metrics/ModuleLength, Metrics/CyclomaticComplexity
end
