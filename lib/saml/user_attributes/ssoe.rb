# frozen_string_literal: true

module SAML
  module UserAttributes
    class SSOe
      include SentryLogging
      SERIALIZABLE_ATTRIBUTES = %i[email first_name middle_name last_name zip gender ssn birth_date
                                   idme_uuid sec_id mhv_icn mhv_correlation_id dslogon_edipi
                                   loa sign_in multifactor].freeze
      IDME_GCID_REGEX = /^(?<idme>\w+)\^PN\^200VIDM\^USDVA\^A$/.freeze

      attr_reader :attributes, :authn_context, :warnings

      def initialize(saml_attributes, authn_context)
        @attributes = saml_attributes # never default this to {}
        @authn_context = authn_context
        @warnings = []
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
      def idme_uuid
        return safe_attr('va_eauth_uid') if safe_attr('va_eauth_csid') == 'idme'

        gcids = safe_attr('va_eauth_gcIds')&.split('|')
        if gcids
          idme_match = gcids.map { |id| IDME_GCID_REGEX.match(id) }.compact.first
          idme_match && idme_match[:idme]
        end
      end

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

      # va_eauth_credentialassurancelevel is supposed to roll up the
      # federated assurance level from credential provider and broker.
      # It is currently returning a value of "2" for DSLogon level 2
      # so we are interpreting any value greater than 1 as "LOA 3".
      def loa_current
        assurance = safe_attr('va_eauth_credentialassurancelevel')&.to_i
        @loa_current ||= assurance.present? && assurance > 1 ? 3 : 1
      rescue NoMethodError, KeyError => e
        @warnings << "loa_current error: #{e.message}"
        @loa_current = 1
      end

      def mhv_loa_highest
        mhv_assurance = safe_attr('va_eauth_mhvassurance')
        SAML::UserAttributes::MHV::PREMIUM_LOAS.include?(mhv_assurance) ? 3 : nil
      end

      def dslogon_loa_highest
        dslogon_assurance = safe_attr('va_eauth_dslogonassurance')
        SAML:: UserAttributes::DSLogon::PREMIUM_LOAS.include?(dslogon_assurance) ? 3 : nil
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

      def loa
        { current: loa_current, highest: loa_highest }
      end

      def sign_in
        SAML::User::AUTHN_CONTEXTS.fetch(@authn_context)
                                  .fetch(:sign_in)
                                  .merge(account_type: account_type)
      end

      def to_hash
        Hash[SERIALIZABLE_ATTRIBUTES.map { |k| [k, send(k)] }]
      end

      private

      def safe_attr(key)
        @attributes[key] == 'NOT_FOUND' ? nil : @attributes[key]
      end
    end
  end
end
