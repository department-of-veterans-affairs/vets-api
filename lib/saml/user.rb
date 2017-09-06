# frozen_string_literal: true
require 'saml/user_attributes/id_me'
require 'saml/user_attributes/mhv'

module SAML
  class User
    attr_reader :saml_response, :attributes, :authn_context, :decorated

    def initialize(saml_response)
      @saml_response = saml_response
      @authn_context = saml_response&.settings&.authn_context
      @attributes = saml_response.attributes
      @decorated = decorator_constant.new(self)
    end

    def last_signed_in
      Time.current.utc
    end

    def loa
      { current: loa_current, highest: loa_highest(attributes) }
    end

    def mhv_user?
      @authn_context == 'mhv'
    end

    def dslogon_user?
      @authn_context == 'dslogon'
    end

    def idme_user?
      !mhv_user? && !dslogon_user?
    end

    def to_hash
      Hash[serializable_attributes.map { |k| [k, @decorated.send(k)] }]
    end

    private

    def serializable_attributes
      @decorated.send(:serializable_attributes) + %i(last_signed_in loa)
    end

    def decorator_constant
      "SAML::UserAttributes::#{@authn_context.upcase}".safe_constantize ||
        SAML::UserAttributes::IdMe
    end

    def loa_current
      @raw_loa ||= REXML::XPath.first(@saml_response.decrypted_document, '//saml:AuthnContextClassRef')&.text
      LOA::MAPPING[@raw_loa]
    end

    def loa_highest(attributes)
      Rails.logger.warn 'LOA.highest is nil!' if (loa = attributes['level_of_assurance']&.to_i).nil?
      loa_highest = loa || loa_current
      Rails.logger.warn 'LOA.highest is less than LOA.current' if loa_highest < loa_current
      [loa_current, loa_highest].max
    end
  end
end
