# frozen_string_literal: true
require 'saml/user_attributes/id_me'
require 'saml/user_attributes/mhv'
require 'saml/user_attributes/dslogon'
require 'sentry_logging'

module SAML
  class User
    include SentryLogging

    attr_reader :saml_response, :attributes, :decorated

    def initialize(saml_response)
      @saml_response = saml_response
      @attributes = saml_response.attributes
      @decorated = decorator_constant.new(self)
      log_warnings_to_sentry!
    end

    def last_signed_in
      Time.current.utc
    end

    def to_hash
      Hash[serializable_attributes.map { |k| [k, @decorated.send(k)] }]
    end

    # we serialize user.rb with this value, in the case of everything other than mhv/dslogon,
    # this will only ever be one of 'dslogon, mhv, or nil'
    # see also: real_authn_context, currently only used by sentry logging to limit scope of changes
    def authn_context
      return 'dslogon' if dslogon?
      return 'mhv' if mhv?
      nil
    end

    def changing_multifactor?
      return false if real_authn_context.nil?
      real_authn_context.include?('multifactor')
    end

    private

    # returns the attributes that are defined below, could be from one of 3 distinct policies, each having different
    # saml responses, hence this weird decorating mechanism, needs improved abstraction to be less weird.
    def serializable_attributes
      @decorated.serializable_attributes + %i(authn_context last_signed_in)
    end

    def dslogon?
      attributes.to_h.keys.include?('dslogon_uuid')
    end

    def mhv?
      attributes.to_h.keys.include?('mhv_uuid')
    end

    # see warnings
    def log_warnings_to_sentry!
      if (warnings = warnings_for_sentry).any?
        warning_context = {
          real_authn_context: real_authn_context,
          authn_context: authn_context,
          warnings: warnings.join(', '),
          loa: @decorated.try(:loa)
        }
        log_message_to_sentry('Issues in SAML Response LOA', :warn, warning_context)
      end
    end

    # will be one of [loa1, loa3, multifactor, dslogon, mhv]
    # this is the real authn-context returned in the response without the use of heuristics
    def real_authn_context
      REXML::XPath.first(saml_response.decrypted_document, '//saml:AuthnContextClassRef')&.text
    end

    # We want to do some logging of when and how the following issues could arise, since loa is
    # derived based on combination of these values, it could raise an exception at any time, hence
    # why we use try/catch. NOTE: The actual exception, if any, will get raised when to_hash is called.
    def warnings_for_sentry
      warnings = []
      warnings << 'attributes[:level_of_assurance] is Nil' if @decorated.try(:idme_loa).blank?
      warnings << 'LOA Current Nil' if @decorated.try(:loa_current).blank?
      warnings << 'LOA Highest Nil' if @decorated.try(:loa_highest).blank?
      if warnings.empty? # only check this one if the other ones were non nil
        warnings << 'LOA Current > LOA Highest' if @decorated.loa_current > @decorated.loa_highest
      end
      warnings
    end

    # should eventually have a special case for multifactor policy and refactor all of this
    # but session controller refactor is premature and can't handle it right now.
    def decorator_constant
      case authn_context
      when 'mhv'; then SAML::UserAttributes::MHV
      when 'dslogon'; then SAML::UserAttributes::DSLogon
      else
        SAML::UserAttributes::IdMe
      end
    end
  end
end
