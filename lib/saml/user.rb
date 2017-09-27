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

    def authn_context
      return 'dslogon' if dslogon?
      return 'mhv' if mhv?
      nil
    end

    private

    def serializable_attributes
      @decorated.serializable_attributes + %i(authn_context last_signed_in)
    end

    # see warnings
    def log_warnings_to_sentry!
      warning_context = {
        authn_context: authn_context || 'nil ~= idme',
        warnings: warnings.join(', '),
        loa: @decorated.try(:loa)
      }
      log_message_to_sentry('Issues in SAML Response LOA', :warn, warning_context)
    end

    # We want to do some logging of when and how the following issues could arise, since loa is
    # derived based on combination of these values, it could raise an exception at any time, hence
    # why we use try/catch. NOTE: The actual exception, if any, will get raised when to_hash is called.
    def warnings
      warnings = []
      warnings << 'attributes[:level_of_assurance] is Nil' if @decorated.try(:idme_loa).blank?
      warnings << 'LOA Current Nil' if @decorated.try(:loa_current).blank?
      warnings << 'LOA Highest Nil' if @decorated.try(:loa_highest).blank?
      if warnings.empty? # only check this one if the other ones were non nil
        warnings << 'LOA Current > LOA Highest' if @decorated.loa_current > @decorated.loa_highest
      end
      warnings
    end

    def dslogon?
      attributes.to_h.keys.include?('dslogon_uuid')
    end

    def mhv?
      attributes.to_h.keys.include?('mhv_uuid')
    end

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
