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

    def to_hash
      Hash[serializable_attributes.map { |k| [k, @decorated.send(k)] }]
    end

    private

    def serializable_attributes
      @decorated.send(:serializable_attributes) + %i(last_signed_in)
    end

    def decorator_constant
      "SAML::UserAttributes::#{@authn_context.upcase}".safe_constantize ||
        SAML::UserAttributes::IdMe
    end
  end
end
