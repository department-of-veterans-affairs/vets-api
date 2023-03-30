# frozen_string_literal: true

module SAML
  module UserAttributes
    class Base
      REQUIRED_ATTRIBUTES = %i[email uuid idme_uuid sec_id loa sign_in multifactor].freeze

      attr_reader :attributes, :authn_context, :tracker_uuid, :warnings

      def initialize(saml_attributes, authn_context, tracker_uuid)
        @attributes = saml_attributes # never default this to {}
        @authn_context = authn_context
        @tracker_uuid = tracker_uuid
        @warnings = []
      end

      # Common Attributes
      # ID.me unique identifier
      def uuid
        idme_uuid
      end

      def idme_uuid
        attributes['uuid']
      end

      def sec_id
        nil
      end

      # ID.me email address associated with the signed-in 'wallet'
      def email
        attributes['email']
      end

      def common_name
        email
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

      # This includes service_name used to sign-in initially, and the account type that is associated with the sign in.
      def sign_in
        SAML::User::AUTHN_CONTEXTS.fetch(authn_context)
                                  .fetch(:sign_in)
                                  .merge(account_type:)
      rescue
        { service_name: 'unknown', account_type: 'N/A' }
      end

      def to_hash
        serializable_attributes.index_with { |k| send(k) }
      end

      # Raise any fatal exceptions due to validation issues
      def validate!; end

      private

      def account_type
        existing_user_identity? ? existing_user_identity.sign_in[:account_type] : 'N/A'
      end

      def existing_user_identity
        return @_existing_user_identity if defined?(@_existing_user_identity)

        @_existing_user_identity = UserIdentity.find(idme_uuid)
      end

      def existing_user_identity?
        existing_user_identity.present?
      end
    end
  end
end
