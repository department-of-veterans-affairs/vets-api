# frozen_string_literal: true

require 'saml/user_attributes/id_me'
require 'saml/user_attributes/mhv'
require 'saml/user_attributes/dslogon'
require 'sentry_logging'
require 'base64'

module SAML
  class User
    include SentryLogging

    AUTHN_CONTEXTS = {
      'http://idmanagement.gov/ns/assurance/loa/1/vets' => { class: 'idme', sign_in: { service_name: 'idme' } },
      'http://idmanagement.gov/ns/assurance/loa/3/vets' => { class: 'idme', sign_in: { service_name: 'idme' } },
      'multifactor' => { class: 'idme', sign_in: { service_name: 'idme' } },
      'myhealthevet_multifactor' => { class: 'idme', sign_in: { service_name: 'myhealthevet' } },
      'myhealthevet_loa3' => { class: 'idme', sign_in: { service_name: 'myhealthevet' } },
      'dslogon_multifactor' => { class: 'idme', sign_in: { service_name: 'dslogon' } },
      'dslogon_loa3' => { class: 'idme', sign_in: { service_name: 'dslogon' } },
      'myhealthevet' => { class: 'myhealthevet', sign_in: { service_name: 'myhealthevet' } },
      'dslogon' => { class: 'dslogon', sign_in: { service_name: 'dslogon' } }
    }.freeze

    attr_reader :saml_response, :saml_attributes, :user_attributes, :existing_user_identity

    def initialize(saml_response)
      @saml_response = saml_response
      @saml_attributes = saml_response.attributes
      @user_attributes = user_attributes_class.new(saml_attributes, authn_context)
      log_warnings_to_sentry!
    end

    def to_hash
      user_attributes.to_hash.merge(Hash[serializable_attributes.map { |k| [k, send(k)] }])
    end

    def changing_multifactor?
      return false if authn_context.nil?
      authn_context.include?('multifactor')
    end

    def verifying?
      return false if authn_context.nil?
      authn_context.include?('_loa3') || authn_context == 'http://idmanagement.gov/ns/assurance/loa/3/vets'
    end

    def idme_proofed?
      verifying? && id_proofed?
    end

    # True if has identity proofed in the past, not that the current saml response is verifying
    def id_proofed?
      user_attributes.idme_loa == 3 || %w[Premium dslogon_loa2 dslogon_loa3].include?(account_type)
    end

    def existing_user_identity?
      changing_multifactor? || verifying? && existing_user_identity.present?
    end

    def existing_user_identity
      @existing_user_identity ||= UserIdentity.find(user_attributes.uuid)
    end

    # This includes the service name used to sign-in initially, and the account type that is associated with the sign in.
    def sign_in
      AUTHN_CONTEXTS.fetch(authn_context).fetch(:sign_in).merge(account_type: account_type, id_proof_type: id_proof_type)
    rescue StandardError
      { service_name: 'unknown', account_type: account_type, id_proof_type: id_proof_type }
    end

    def id_proof_type
      return 'idme' if idme_proofed?
      return 'idme-initial' if user_attributes.idme_loa == 3
      return 'myhealthevet' if account_type == 'Premium'
      return 'dslogon' if %w[2 3].include?(account_type)
      return 'error' if account_type == 'error'
      'not-verified'
    end

    # This corresponds to "Basic", "Advanced", "Premium", "1", "3"
    def account_type
      case authn_context
      when 'myhealthevet'
        user_attributes.mhv_account_type # Signed in MHV
      when 'dslogon'
        user_attributes.dslogon_assurance # Signed in DS Logon
      else
        if existing_user_identity? # Signed in but verifying / multifactoring, fetch from original identity
          existing_user_identity.sign_in.fetch(:account_type, 'N/A')
        else
          'N/A' # Signed in as ID.me (either LOA1 or LOA3)
        end
      end
    rescue StandardError
      'error'
    end

    private

    # returns the attributes that are defined below, could be from one of 3 distinct policies, each having different
    # saml responses, hence this weird decorating mechanism, needs improved abstraction to be less weird.
    def serializable_attributes
      %i[authn_context sign_in]
    end

    # see warnings
    # NOTE: The actual exception, if any, should get raised when to_hash is called. Hence "suppress"
    def log_warnings_to_sentry!
      suppress(Exception) do
        if (warnings = warnings_for_sentry).any?
          warning_context = {
            authn_context: authn_context,
            warnings: warnings.join(', '),
            loa: user_attributes.loa
          }
          log_message_to_sentry("Issues in SAML Response - #{authn_context}", :warn, warning_context)
        end
      end
    end

    # will be one of KNOWN_AUTHN_CONTEXTS
    # this is the real authn-context returned in the response without the use of heuristics
    def authn_context
      REXML::XPath.first(saml_response.decrypted_document, '//saml:AuthnContextClassRef')&.text
    # this is to add additional context when we cannot parse for authn_context
    rescue NoMethodError
      base64encodedpayload = Base64.encode64(saml_response&.response)
      Raven.extra_context(
        base64encodedpayload: base64encodedpayload,
        attributes: saml_response&.attributes&.to_h
      )
      Raven.tags_context(controller_name: 'sessions', sign_in_method: 'not-signed-in:error')
      Rails.logger.error(
        'SSO: No AuthnContext in SAMLResponse', saml_response: base64encodedpayload
      )
      raise
    end
    alias real_authn_context authn_context

    # We want to do some logging of when and how the following issues could arise, since loa is
    # derived based on combination of these values, it could raise an exception at any time, hence
    # why we use try/catch.
    def warnings_for_sentry
      warnings = []
      warnings << 'LOA Current Nil' if user_attributes.loa_current.blank?
      warnings << 'LOA Highest Nil' if user_attributes.loa_highest.blank?
      warnings
    end

    # should eventually have a special case for multifactor policy and refactor all of this
    # but session controller refactor is premature and can't handle it right now.
    def user_attributes_class
      case authn_context
      when 'myhealthevet'; then SAML::UserAttributes::MHV
      when 'dslogon'; then SAML::UserAttributes::DSLogon
      else
        SAML::UserAttributes::IdMe
      end
    end
  end
end
