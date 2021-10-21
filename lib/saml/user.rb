# frozen_string_literal: true

require 'saml/user_attributes/id_me'
require 'saml/user_attributes/mhv'
require 'saml/user_attributes/dslogon'
require 'saml/user_attributes/ssoe'
require 'sentry_logging'
require 'base64'

module SAML
  class User
    include SentryLogging

    AUTHN_CONTEXTS = {
      LOA::IDME_LOA1_VETS => { loa_current: '1', sign_in: { service_name: 'idme' } },
      LOA::IDME_LOA3_VETS => { loa_current: '3', sign_in: { service_name: 'idme' } },
      LOA::IDME_LOA3 => { loa_current: '3', sign_in: { service_name: 'idme' } },
      'multifactor' => { loa_current: nil, sign_in: { service_name: 'idme' } },
      'myhealthevet_multifactor' => { loa_current: nil, sign_in: { service_name: 'myhealthevet' } },
      'myhealthevet_loa3' => { loa_current: '3', sign_in: { service_name: 'myhealthevet' } },
      'dslogon_multifactor' => { loa_current: nil, sign_in: { service_name: 'dslogon' } },
      'dslogon_loa3' => { loa_current: '3', sign_in: { service_name: 'dslogon' } },
      'myhealthevet' => { loa_current: nil, sign_in: { service_name: 'myhealthevet' } },
      'dslogon' => { loa_current: nil, sign_in: { service_name: 'dslogon' } }
    }.freeze
    UNKNOWN_AUTHN_CONTEXT = 'unknown'
    attr_reader :saml_response, :saml_attributes, :user_attributes, :tracker_uuid

    def initialize(saml_response)
      @saml_response = saml_response
      @saml_attributes = saml_response.attributes
      @tracker_uuid = saml_response.in_response_to

      Raven.extra_context(
        saml_attributes: saml_attributes&.to_h,
        saml_response: Base64.encode64(saml_response&.response || '')
      )

      @user_attributes = user_attributes_class.new(saml_attributes, authn_context, tracker_uuid)

      Raven.tags_context(
        sign_in_service_name: user_attributes.sign_in&.fetch(:service_name, nil),
        sign_in_account_type: user_attributes.sign_in&.fetch(:account_type, nil)
      )
      log_warnings_to_sentry
    end

    def validate!
      @user_attributes.validate!
    end

    def changing_multifactor?
      return false if authn_context.nil?

      authn_context.include?('multifactor')
    end

    def to_hash
      user_attributes.to_hash.merge(serializable_attributes.index_with { |k| send(k) })
    end

    private

    def serializable_attributes
      %i[authn_context]
    end

    def log_warnings_to_sentry
      user_attributes.to_hash

      if user_attributes.warnings.any?
        warning_context = {
          authn_context: authn_context,
          warnings: user_attributes.warnings.uniq.join(', ')
        }

        log_message_to_sentry('SAML RESPONSE WARNINGS', :warn, warning_context)
      end
    end

    # will be one of AUTHN_CONTEXTS.keys
    def authn_context
      saml_response.authn_context_text
    rescue
      Raven.tags_context(controller_name: 'sessions', sign_in_method: 'not-signed-in:error')
      raise
    end

    def issuer
      saml_response.issuer_text
    rescue
      Raven.tags_context(controller_name: 'sessions', sign_in_method: 'not-signed-in:error')
      raise
    end

    def authenticated_by_ssoe
      issuer&.match?(/eauth\.va\.gov/) == true
    end

    # SSOe Issuer value is https://int.eauth.va.gov/FIM/sps/saml20fedCSP/saml20
    def user_attributes_class
      return SAML::UserAttributes::SSOe if authenticated_by_ssoe

      case authn_context
      when 'myhealthevet', 'myhealthevet_multifactor'
        SAML::UserAttributes::MHV
      when 'dslogon', 'dslogon_multifactor'
        SAML::UserAttributes::DSLogon
      when 'multifactor', 'dslogon_loa3', 'myhealthevet_loa3', LOA::IDME_LOA3, LOA::IDME_LOA3_VETS, LOA::IDME_LOA1_VETS
        SAML::UserAttributes::IdMe
      else
        Raven.tags_context(
          authn_context: authn_context,
          controller_name: 'sessions',
          sign_in_method: 'not-signed-in:error'
        )
        raise 'InvalidAuthnContext'
      end
    end
  end
end
