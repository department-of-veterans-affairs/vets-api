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
      instance_double(OneLogin::RubySaml::Response, attributes: attributes,
                                                    decrypted_document: document_partial(authn_context),
                                                    is_a?: true,
                                                    is_valid?: true,
                                                    response: 'mock-response')
    end
    # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

    def build_invalid_saml_response(options)
      options = options.reverse_merge(is_valid?: false, is_a?: true)
      instance_double(OneLogin::RubySaml::Response, options)
    end

    def invalid_saml_response
      build_invalid_saml_response(in_response_to: uuid,
                                  decrypted_document: document_partial)
    end

    def saml_response_click_deny
      build_invalid_saml_response(
        in_response_to: uuid,
        decrypted_document: nil,
        errors: ['ruh roh'],
        status_message: 'Subject did not consent to attribute release'
      )
    end

    def saml_response_too_late
      build_invalid_saml_response(
        status_message: nil,
        in_response_to: uuid,
        decrypted_document: document_partial,
        errors: [
          'Current time is on or after NotOnOrAfter condition (2017-02-10 17:03:40 UTC >= 2017-02-10 17:03:30 UTC)'
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
        status_message: SSOService::DEFAULT_ERROR_MESSAGE, in_response_to: uuid,
        decrypted_document: document_partial,
        errors: [
          'The status code of the Response was not Success, was Requester => NoAuthnContext -> AuthnRequest without ' \
          'an authentication context.'
        ]
      )
    end

    def saml_response_multi_error
      build_invalid_saml_response(
        status_message: 'Subject did not consent to attribute release', in_response_to: uuid,
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
          'dslogon_idauthn_context' => ['ssn'],
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
      end
    end
  end
  # rubocop:enable Metrics/MethodLength, Metrics/ModuleLength
end
