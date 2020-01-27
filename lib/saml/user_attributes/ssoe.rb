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
        return mhv_loa_current if mhv_loa_current
        return dslogon_loa_current if dslogon_loa_current

        @loa_current ||=
          if authn_context.include?('multifactor')
            existing_user_identity.loa.fetch(:current, 1).to_i
          else
            SAML::User::AUTHN_CONTEXTS.fetch(authn_context).fetch(:loa_current, 1).to_i
          end
      rescue NoMethodError, KeyError => e
        @warnings << "loa_current error: #{e.message}"
        @loa_current = 1
      end

      def mhv_loa_current
        if attributes['mhv_profile']
          mhv_profile = JSON.parse(attributes['mhv_profile'])
          mhv_account_type = mhv_profile['accountType']
          SAML::UserAttributes::MHV::PREMIUM_LOAS.include?(mhv_account_type) ? 3 : 1
        end
      end

      def dslogon_loa_current
        if attributes['dslogon_assurance']
          dslogon_assurance = attributes['dslogon_assurance']
          SAML:: UserAttributes::DSLogon::PREMIUM_LOAS.include?(dslogon_assurance) ? 3 : 1
        end
      end

      # This is the ID.me highest level of assurance attained
      def loa_highest
        attributes['va_eauth_credentialassurancelevel']&.to_i
      end

      def multifactor
        attributes['multifactor']
      end

      def account_type
        loa_current
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
