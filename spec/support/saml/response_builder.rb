# frozen_string_literal: true

module SAML
  # rubocop:disable Metrics/MethodLength, Metrics/ModuleLength
  module ResponseBuilder
    MHV_PREMIUM_ATYPE = [
      '{"accountType":"Premium","availableServices":{"21":"VA Medications","4":"Secure Messaging","3":"VA Allergies"' \
      ',"2":"Rx Refill","12":"Blue Button (all VA data)","1":"Blue Button self entered data.","11":"Blue Button (DoD)' \
      ' Military Service Information"}}'
    ].freeze

    def create_user_identity(authn_context:, level_of_assurance:, attributes:, issuer: nil)
      saml = build_saml_response(
        authn_context:,
        level_of_assurance:,
        attributes:,
        issuer:
      )
      saml_user = SAML::User.new(saml)
      user = create(:user, :response_builder, saml_user.to_hash)
      user.identity
    end

    # rubocop:disable Metrics/ParameterLists
    def build_saml_response(
      authn_context:, level_of_assurance:,
      attributes: nil, issuer: nil, existing_attributes: nil, in_response_to: nil
    )
      verifying = [LOA::IDME_LOA3, LOA::IDME_LOA3_VETS, 'myhealthevet_loa3'].include?(authn_context)

      if authn_context.present?
        if authn_context.include?('multifactor') && existing_attributes.present?
          previous_context = authn_context.gsub(/multifactor|_multifactor/, '').presence || LOA::IDME_LOA1_VETS
          create_user_identity(
            authn_context: previous_context,
            level_of_assurance:,
            attributes: existing_attributes,
            issuer:
          )
        end

        if verifying && existing_attributes.present?
          previous_context = authn_context.gsub(/_loa3/, '')
                                          .gsub(%r{loa/3/vets}, 'loa/1/vets')
                                          .gsub(%r{loa/3}, 'loa/1/vets')
          create_user_identity(
            authn_context: previous_context,
            level_of_assurance: '1',
            attributes: existing_attributes,
            issuer:
          )
        end
      end

      saml_response = SAML::Responses::Login.new(document_partial(authn_context).to_s)
      allow(saml_response).to receive_messages(issuer_text: issuer, assertion_encrypted?: true, attributes:,
                                               validate: true, decrypted_document: document_partial(authn_context),
                                               in_response_to:)
      saml_response
    end
    # rubocop:enable Metrics/ParameterLists

    def build_invalid_saml_response(in_response_to:, decrypted_document:, errors:, status_message:)
      saml_response = SAML::Responses::Login.new(decrypted_document.to_s)
      allow(saml_response).to receive_messages(validate: false, errors:, in_response_to:,
                                               decrypted_document:, status_message:)
      saml_response
    end

    def invalid_saml_response
      build_invalid_saml_response(in_response_to: user.uuid,
                                  decrypted_document: document_partial)
    end

    def saml_response_click_deny
      build_invalid_saml_response(
        in_response_to: user.uuid,
        decrypted_document: document_partial,
        errors: ['The status code of the Response was not Success, was Responder => AuthnFailed ' \
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
        in_response_to: user.uuid,
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
        in_response_to: user.uuid,
        decrypted_document: document_partial,
        errors: [
          'Current time is earlier than NotBefore condition (2017-02-10 17:03:30 UTC) < 2017-02-10 17:03:40 UTC)'
        ]
      )
    end

    def saml_response_unknown_error
      build_invalid_saml_response(
        status_message: 'Default generic identity provider error',
        in_response_to: user.uuid,
        decrypted_document: document_partial,
        errors: [
          'The status code of the Response was not Success, was Requester => NoAuthnContext -> AuthnRequest without ' \
          'an authentication context.'
        ]
      )
    end

    def saml_response_multi_error(in_response_to = nil)
      build_invalid_saml_response(
        status_message: 'Subject did not consent to attribute release',
        in_response_to: in_response_to || user.uuid,
        decrypted_document: document_partial,
        errors: ['Subject did not consent to attribute release', 'Other random error']
      )
    end

    def saml_response_detail_error(status_detail_xml)
      build_invalid_saml_response(
        status_message: 'Status Detail Error Message',
        in_response_to: user.uuid,
        decrypted_document: document_status_detail(status_detail_xml),
        errors: %w[Test1 Test2 Test3]
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

    def document_status_detail(status = '')
      REXML::Document.new(
        <<-XML
        <samlp:Response
          xmlns:ds="http://www.w3.org/2000/09/xmldsig#"
          xmlns:fim="urn:ibm:names:ITFIM:saml"
          xmlns:saml="urn:oasis:names:tc:SAML:2.0:assertion"
          xmlns:samlp="urn:oasis:names:tc:SAML:2.0:protocol" Destination="https://api.va.gov/v1/sessions/callback" ID="FIMRSP_9bbcd6a3-0175-10e5-8532-9199cd4142f8" InResponseTo="_a9ea0b44-5b5d-40dd-ae46-de5dafa71983" IssueInstant="2020-11-06T04:07:25Z" Version="2.0">
          <saml:Issuer Format="urn:oasis:names:tc:SAML:2.0:nameid-format:entity">https://eauth.va.gov/isam/sps/saml20idp/saml20</saml:Issuer>
          <samlp:Status>
            #{status}
          </samlp:Status>
        </samlp:Response>
        XML
      )
    end
  end
  # rubocop:enable Metrics/MethodLength, Metrics/ModuleLength
end
