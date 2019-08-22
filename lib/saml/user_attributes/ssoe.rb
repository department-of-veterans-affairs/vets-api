# frozen_string_literal: true

module SAML
  module UserAttributes
    class SSOe < Base
      include SentryLogging
      SSOE_SERIALIZABLE_ATTRIBUTES = %i[first_name middle_name last_name zip gender ssn birth_date].freeze
      MERGEABLE_IDENTITY_ATTRIBUTES = %i[mhv_icn mhv_correlation_id dslogon_edipi sign_in].freeze

      # Denoted as "CSP user ID" in SSOe docs; required attribute for LOA >= 2
      def uuid
        attributes['va_eauth_uid']
      end

      ### Personal attributes

      def first_name
        attributes['va_eauth_firstname']
      end

      def middle_name
        attributes['va_eauth_middlename']
      end

      def last_name
        attributes['va_eauth_lastname']
      end

      def zip
        attributes['va_eauth_postalcode']
      end

      def gender
        attributes['va_eauth_gender']&.chars&.first&.upcase
      end

      # This attribute may sometimes be TIN, Patient identifier, etc.
      # It is not guaranteed to be a SSN
      def ssn
        attributes['va_eauth_pnid']&.delete('-') if attributes['va_eauth_pnidtype'] == 'SSN'
      end

      def birth_date
        attributes['va_eauth_birthDate_v1']
      end

      def email
        attributes['va_eauth_emailaddress']
      end

      ### Identifiers

      def mhv_icn
        attributes['va_eauth_icn']
      end

      def mhv_correlation_id
        attributes['va_eauth_mhvien']
      end

      def dslogon_edipi
        attributes['va_eauth_dodedipnid']
      end

      def loa_current
        attributes['va_eauth_credentialassurancelevel']&.to_i
      end

      ### Unsupported attributes

      # TODO: This should be the ID.me highest level of assurance attained;
      # VA IAM team to get this integrated and propagated from ID.me
      # double check attribute name after VA IAM finalizes
      def loa_highest
        attributes['level_of_assurance']&.to_i
      end

      # TODO: This is not supported by SSOe. Denotes whether ID.me wallet is MFA
      # enabled. VA IAM team to get this integrated and propagated from ID.me
      # Investigate front-end use of this attribute to determine
      # what this attribute is used for
      def multifactor
        attributes['multifactor']
      end

      def account_type
        attributes['level_of_assurance']
      end

      def sign_in
        if existing_user_identity?
          existing_user_identity.sign_in
        else
          super
        end
      end

      private

      def serializable_attributes
        REQUIRED_ATTRIBUTES + SSOE_SERIALIZABLE_ATTRIBUTES + MERGEABLE_IDENTITY_ATTRIBUTES
      end
    end
  end
end
