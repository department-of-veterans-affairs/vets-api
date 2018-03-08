# frozen_string_literal: true

require 'saml/user_attributes/id_me'
require 'saml/user_attributes/mhv'
require 'saml/user_attributes/dslogon'
require 'sentry_logging'

module SAML
  class User
    include SentryLogging

    attr_reader :saml_response, :saml_attributes, :user_attributes

    def initialize(saml_response)
      @saml_response = saml_response
      @saml_attributes = saml_response.attributes
      @user_attributes = user_attributes_class.new(saml_attributes, real_authn_context)
      log_warnings_to_sentry!
    end

    def changing_multifactor?
      return false if real_authn_context.nil?
      real_authn_context.include?('multifactor')
    end

    def to_hash
      user_attributes.to_hash.merge(Hash[serializable_attributes.map { |k| [k, send(k)] }])
    end

    private

    # we serialize user.rb with this value, in the case of everything other than mhv/dslogon,
    # this will only ever be one of 'dslogon, mhv, or nil'
    def authn_context
      return 'dslogon' if dslogon?
      return 'myhealthevet' if mhv?
      nil
    end

    # returns the attributes that are defined below, could be from one of 3 distinct policies, each having different
    # saml responses, hence this weird decorating mechanism, needs improved abstraction to be less weird.
    def serializable_attributes
      %i[authn_context]
    end

    def dslogon?
      saml_attributes.to_h.keys.include?('dslogon_uuid')
    end

    def mhv?
      saml_attributes.to_h.keys.include?('mhv_uuid')
    end

    # see warnings
    # NOTE: The actual exception, if any, should get raised when to_hash is called. Hence "suppress"
    def log_warnings_to_sentry!
      suppress(Exception) do
        if (warnings = warnings_for_sentry).any?
          warning_context = {
            real_authn_context: real_authn_context,
            authn_context: authn_context,
            warnings: warnings.join(', '),
            loa: user_attributes.loa
          }
          log_message_to_sentry("Issues in SAML Response - #{real_authn_context}", :warn, warning_context)
        end
      end
    end

    # will be one of [loa1, loa3, multifactor, dslogon, mhv]
    # this is the real authn-context returned in the response without the use of heuristics
    def real_authn_context
      REXML::XPath.first(saml_response.decrypted_document, '//saml:AuthnContextClassRef')&.text
    # this is to add additional context when we cannot parse for authn_context
    rescue NoMethodError
      binding.pry
      Raven.extra_context(saml_response: saml_response.response)
      Raven.user_context(saml_response.attributes.to_h)
      Raven.tags_context(controller_name: 'sessions', sign_in_method: 'not-signed-in:error')
      raise
    end

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
