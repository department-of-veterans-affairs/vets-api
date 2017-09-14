# frozen_string_literal: true
require 'saml/user_attributes/id_me'
require 'saml/user_attributes/mhv'
require 'saml/user_attributes/dslogon'

module SAML
  class User
    attr_reader :saml_response, :attributes, :decorated

    def initialize(saml_response)
      @saml_response = saml_response
      @attributes = saml_response.attributes
      @decorated = decorator_constant.new(self)
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
      @decorated.send(:serializable_attributes) + %i(last_signed_in)
    end

    def dslogon?
      attributes.to_h.keys.include?('dslogon_uuid')
    end

    def mhv?
      attributes.to_h.keys.include?('mhv_uuid')
    end

    def decorator_constant
      case authn_context
      when 'mhv'; then 'SAML::UserAttributes::MHV'.safe_constantize
      when 'dslogon'; then 'SAML::UserAttributes::DSLogon'.safe_constantize
      else
        SAML::UserAttributes::IdMe
      end
    end
  end
end
