# frozen_string_literal: true

module SAML
  module UserAttributes
    class Base
      REQUIRED_ATTRIBUTES = %i(email uuid loa multifactor).freeze

      attr_reader :attributes, :real_authn_context

      def initialize(saml_attributes, real_authn_context)
        @attributes = saml_attributes
        @real_authn_context = real_authn_context
      end

      # Common Attributes
      # ID.me unique identifier
      def uuid
        attributes['uuid']
      end

      # ID.me email address associated with the signed-in 'wallet'
      def email
        attributes['email']
      end

      # ID.me level of assurance, provided by all authn_contexts
      def idme_loa
        attributes['level_of_assurance']&.to_i
      end

      # ID.me boolean value that specifies whether the signed-in 'wallet' has multifactor enabled or not
      def multifactor
        attributes['multifactor']
      end

      # This field is derived from methods implemented on child classes
      def loa
        { current: loa_current, highest: loa_highest }
      end

      def to_hash
        Hash[serializable_attributes.map { |k| [k, send(k)] }]
      end
    end
  end
end
