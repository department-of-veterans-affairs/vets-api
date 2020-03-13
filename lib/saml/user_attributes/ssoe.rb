# frozen_string_literal: true

module SAML
  module UserAttributes
    class SSOe < Base
      include SentryLogging
      SSOE_SERIALIZABLE_ATTRIBUTES = %i[first_name middle_name last_name zip gender ssn birth_date].freeze
      MERGEABLE_IDENTITY_ATTRIBUTES = %i[sec_id mhv_icn mhv_correlation_id dslogon_edipi sign_in].freeze

      # Denoted as "CSP user ID" in SSOe docs; required attribute for LOA >= 2
      def uuid
        safe_attr('va_eauth_uid')
      end

      ### Personal attributes

      def first_name
        safe_attr('va_eauth_firstname')
      end

      def middle_name
        safe_attr('va_eauth_middlename')
      end

      def last_name
        safe_attr('va_eauth_lastname')
      end

      def zip
        safe_attr('va_eauth_postalcode')
      end

      def gender
        gender = safe_attr('va_eauth_gender')&.chars&.first&.upcase
        %w[M F].include?(gender) ? gender : nil
      end

      # This attribute may sometimes be TIN, Patient identifier, etc.
      # It is not guaranteed to be a SSN
      def ssn
        safe_attr('va_eauth_pnid')&.delete('-') if safe_attr('va_eauth_pnidtype') == 'SSN'
      end

      def birth_date
        safe_attr('va_eauth_birthDate_v1')
      end

      def email
        safe_attr('va_eauth_emailaddress')
      end

      ### Identifiers
      def sec_id
        safe_attr('va_eauth_secid')
      end

      def mhv_icn
        safe_attr('va_eauth_icn')
      end

      def mhv_correlation_id
        safe_attr('va_eauth_mhvien')
      end

      def dslogon_edipi
        safe_attr('va_eauth_dodedipnid')
      end

      def loa_current
        @loa_current ||= safe_attr('va_eauth_credentialassurancelevel')&.to_i
      rescue NoMethodError, KeyError => e
        @warnings << "loa_current error: #{e.message}"
        @loa_current = 1
      end

      def mhv_loa_highest
        if safe_attr('va_eauth_mhvassurance')
          mhv_assurance = safe_attr('va_eauth_mhvassurance')
          SAML::UserAttributes::MHV::PREMIUM_LOAS.include?(mhv_assurance) ? 3 : nil
        end
      end

      def dslogon_loa_highest
        if safe_attr('va_eauth_dslogonassurance')
          dslogon_assurance = safe_attr('va_eauth_dslogonassurance')
          SAML:: UserAttributes::DSLogon::PREMIUM_LOAS.include?(dslogon_assurance) ? 3 : nil
        end
      end

      # This is the ID.me highest level of assurance attained
      def loa_highest
        result = mhv_loa_highest
        result ||= dslogon_loa_highest
        result ||= %w[2 classic_loa3].include?(safe_attr('va_eauth_ial_idme_highest')) ? 3 : 1
        result
      end

      def multifactor
        safe_attr('va_eauth_multifactor')&.downcase == 'true'
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

      def safe_attr(key)
        attributes[key] == 'NOT_FOUND' ? nil : attributes[key]
      end

      def serializable_attributes
        REQUIRED_ATTRIBUTES + SSOE_SERIALIZABLE_ATTRIBUTES + MERGEABLE_IDENTITY_ATTRIBUTES
      end
    end
  end
end
