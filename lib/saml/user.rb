# frozen_string_literal: true

require 'saml/user_attributes/id_me'
require 'saml/user_attributes/mhv'
require 'saml/user_attributes/dslogon'
require 'sentry_logging'
require 'base64'

module SAML
  class User
    include SentryLogging

    LOA1 = LOA::IDME_LOA1
    LOA3 = LOA::IDME_LOA3

    AUTHN_CONTEXTS = {
      LOA1 => { loa_current: '1', sign_in: { service_name: 'idme' } },
      LOA3 => { loa_current: '3', sign_in: { service_name: 'idme' } },
      'multifactor' => { loa_current: nil, sign_in: { service_name: 'idme' } },
      'myhealthevet_multifactor' => { loa_current: nil, sign_in: { service_name: 'myhealthevet' } },
      'myhealthevet_loa3' => { loa_current: '3', sign_in: { service_name: 'myhealthevet' } },
      'dslogon_multifactor' => { loa_current: nil, sign_in: { service_name: 'dslogon' } },
      'dslogon_loa3' => { loa_current: '3', sign_in: { service_name: 'dslogon' } },
      'myhealthevet' => { loa_current: nil, sign_in: { service_name: 'myhealthevet' } },
      'dslogon' => { loa_current: nil, sign_in: { service_name: 'dslogon' } }
    }.freeze

    attr_reader :saml_response, :saml_attributes, :user_attributes

    def initialize(saml_response)
      @saml_response = saml_response
      @saml_attributes = saml_response.attributes
      @user_attributes = user_attributes_class.new(saml_attributes, authn_context)
      set_raven_context_and_log_warnings_to_sentry
    end

    def changing_multifactor?
      return false if authn_context.nil?
      authn_context.include?('multifactor')
    end

    def to_hash
      user_attributes.to_hash.merge(Hash[serializable_attributes.map { |k| [k, send(k)] }])
    end

    private

    # returns the attributes that are defined below, could be from one of 3 distinct policies, each having different
    # saml responses, hence this weird decorating mechanism, needs improved abstraction to be less weird.
    def serializable_attributes
      %i[authn_context]
    end

    # NOTE: The actual exception, if any, should get raised when to_hash is called. Hence "suppress"
    def set_raven_context_and_log_warnings_to_sentry
      suppress(Exception) do
        extra_context = {
          uuid: attributes['uuid'],
          loa: user_attributes.loa,
          idme_level_of_assurance: attributes['level_of_assurance'],
          authn_context: authn_context
        }
        Raven.extra_context(extra_context)

        if user_attributes.warnings.any?
          warning_context = { warnings: warnings.uniq.join(', ') }
          log_message_to_sentry("SAML RESPONSE WARNINGS  - #{authn_context}", :warn, warning_context)
        end
      end
    end

    # will be one of AUTHN_CONTEXTS.keys
    # this is the real authn-context returned in the response without the use of heuristics
    def authn_context
      REXML::XPath.first(saml_response.decrypted_document, '//saml:AuthnContextClassRef')&.text
    rescue StandardError
      Raven.extra_context(
        base64encodedpayload: Base64.encode64(saml_response&.response),
        attributes: saml_response&.attributes&.to_h
      )
      Raven.tags_context(controller_name: 'sessions', sign_in_method: 'not-signed-in:error')
      raise
    end

    # should eventually have a special case for multifactor policy and refactor all of this
    # but session controller refactor is premature and can't handle it right now.
    def user_attributes_class
      case authn_context
      when 'myhealthevet'; then SAML::UserAttributes::MHV
      when 'dslogon'; then SAML::UserAttributes::DSLogon
      when 'myhealthevet_loa3', 'myhealthevet_multifactor', 'dslogon_loa3', 'dslogon_multifactor', LOA1, LOA3
        SAML::UserAttributes::IdMe
      else
        log_message_to_sentry("INVALID AUTHN_CONTEXT - #{authn_context}", :warn)
        SAML::UserAttributes::IdMe
      end
    end
  end
end
