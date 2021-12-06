# frozen_string_literal: true

require 'saml/errors'
require 'digest'
require 'identity/parsers/gc_ids'

module SAML
  module UserAttributes
    class SSOe
      include SentryLogging
      include Identity::Parsers::GCIds
      SERIALIZABLE_ATTRIBUTES = %i[email first_name middle_name last_name common_name zip gender ssn
                                   birth_date uuid idme_uuid logingov_uuid verified_at sec_id
                                   mhv_icn mhv_correlation_id mhv_account_type
                                   edipi loa sign_in multifactor participant_id birls_id icn
                                   person_types].freeze
      INBOUND_AUTHN_CONTEXT = 'urn:oasis:names:tc:SAML:2.0:ac:classes:Password'

      attr_reader :attributes, :authn_context, :tracker_uuid, :warnings

      def initialize(saml_attributes, authn_context, tracker_uuid)
        @attributes = saml_attributes # never default this to {}
        @authn_context = authn_context
        @tracker_uuid = tracker_uuid
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

      def common_name
        safe_attr('va_eauth_commonname')
      end

      def participant_id
        sanitize_id(mvi_ids[:vba_corp_id])
      end

      def birls_id
        sanitize_id(mvi_ids[:birls_id])
      end

      def icn
        mvi_ids[:icn]
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
        bd = safe_attr('va_eauth_birthDate_v1')
        begin
          Date.parse(bd).strftime('%Y-%m-%d')
        rescue TypeError, ArgumentError
          nil
        end
      end

      def email
        safe_attr('va_eauth_emailaddress')
      end

      # Returns an array because a person can have multipe types.
      def person_types
        safe_attr('va_eauth_persontype')&.split('|') || []
      end

      ### Identifiers
      def uuid
        return idme_uuid if idme_uuid
        return logingov_uuid if logingov_uuid
        # The sec_id is not a UUID, and while unique this has a potential to cause issues
        # in downstream processes that are expecting a user UUID to be 32 bytes. For
        # example, if there is a log filtering process that was striping out any 32 byte
        # id, an 10 byte sec id would be missed. Using a one way UUID hash, will convert
        # the sec id to a 32 byte unique identifier so that any downstream processes will
        # will treat it exactly the same as a typical 32 byte ID.me identifier.
        return Digest::UUID.uuid_v3('sec-id', sec_id).tr('-', '') if sec_id

        raise Common::Exceptions::InvalidResource, @attributes
      end

      def idme_uuid
        return safe_attr('va_eauth_uid') if csid == SAML::User::IDME_CSID

        mvi_ids[:idme_id]
      end

      def logingov_uuid
        return safe_attr('va_eauth_uid') if csid == SAML::User::LOGINGOV_CSID

        mvi_ids[:logingov_id]
      end

      # only applies to Login.gov IAL2 verification
      # used to automatically upcert IAL1 users without additional service calls
      def verified_at
        safe_attr('va_eauth_verifiedAt')
      end

      def sec_id
        safe_attr('va_eauth_secid')
      end

      def mhv_icn
        safe_attr('va_eauth_icn')
      end

      def mhv_correlation_id
        safe_attr('va_eauth_mhvuuid') || safe_attr('va_eauth_mhvien')&.split(',')&.first
      end

      def mhv_account_type
        safe_attr('va_eauth_mhvassurance')
      end

      def dslogon_account_type
        safe_attr('va_eauth_dslogonassurance')
      end

      def edipi
        safe_attr('va_eauth_dodedipnid')&.split(',')&.first
      end

      def sponsor_dod_epi_pn_id
        safe_attr('va_eauth_sponsordodedipnid')&.split(',')&.first
      end

      # va_eauth_credentialassurancelevel is supposed to roll up the
      # federated assurance level from credential provider and broker.
      # It is currently returning a value of "2" for DSLogon level 2
      # so we are interpreting any value greater than 1 as "LOA 3".
      def loa_current
        assurance =
          if csid == 'logingov'
            safe_attr('va_eauth_ial')&.to_i
          else
            safe_attr('va_eauth_credentialassurancelevel')&.to_i
          end
        @loa_current ||= assurance.present? && assurance > 1 ? 3 : 1
      rescue NoMethodError, KeyError => e
        @warnings << "loa_current error: #{e.message}"
        @loa_current = 1
      end

      def mhv_loa_highest
        mhv_assurance = mhv_account_type
        SAML::UserAttributes::MHV::PREMIUM_LOAS.include?(mhv_assurance) ? 3 : nil
      end

      def dslogon_loa_highest
        dslogon_assurance = dslogon_account_type
        SAML::UserAttributes::DSLogon::PREMIUM_LOAS.include?(dslogon_assurance) ? 3 : nil
      end

      # This is the ID.me highest level of assurance attained
      def loa_highest
        result = mhv_loa_highest
        result ||= dslogon_loa_highest
        result ||= %w[2 classic_loa3].include?(safe_attr('va_eauth_ial_idme_highest')) ? 3 : 1
        result
      end

      def multifactor
        if csid == SAML::User::LOGINGOV_CSID
          safe_attr('va_eauth_aal') == AAL::TWO
        else
          safe_attr('va_eauth_multifactor')&.downcase == 'true'
        end
      end

      def account_type
        result = mhv_account_type
        result ||= dslogon_account_type
        result ||= 'N/A'
        result
      end

      def loa
        { current: loa_current, highest: [loa_current, loa_highest].max }
      end

      def transactionid
        safe_attr('va_eauth_transactionid')
      end

      def sign_in
        sign_in = if @authn_context == INBOUND_AUTHN_CONTEXT
                    { service_name: csid == SAML::User::MHV_ORIGINAL_CSID ? SAML::User::MHV_MAPPED_CSID : csid }
                  else
                    SAML::User::AUTHN_CONTEXTS.fetch(@authn_context).fetch(:sign_in)
                  end
        sign_in.merge(account_type: account_type)
      end

      def to_hash
        SERIALIZABLE_ATTRIBUTES.index_with { |k| send(k) }
      end

      # Raise any fatal exceptions due to validation issues
      def validate!
        if should_raise_missing_uuid_error
          data = SAML::UserAttributeError::ERRORS[:uuid_missing].merge({ identifier: mhv_icn })
          raise SAML::UserAttributeError, data
        end

        multiple_id_validations
      end

      private

      def multiple_id_validations
        # EDIPI, ICN, and CORP ID all trigger errors if multiple unique IDs are found
        raise SAML::UserAttributeError, SAML::UserAttributeError::ERRORS[:multiple_edipis] if edipi_mismatch?
        raise SAML::UserAttributeError, SAML::UserAttributeError::ERRORS[:mhv_icn_mismatch] if mhv_icn_mismatch?
        raise SAML::UserAttributeError, SAML::UserAttributeError::ERRORS[:multiple_corp_ids] if corp_id_mismatch?

        # temporary conditional validation for MHV, can be only a warning if user is MHV inbound-outbound
        conditional_validate_mhv_ids

        # SEC & BIRLS multiple IDs are more common, only log a warning
        if sec_id_mismatch?
          log_message_to_sentry(
            'User attributes contains multiple sec_id values',
            'warn',
            { sec_id: @attributes['va_eauth_secid'] }
          )
        end

        if birls_id_mismatch?
          log_message_to_sentry(
            'User attributes contain multiple distinct BIRLS ID values.',
            'warn',
            { birls_ids: @attributes['va_eauth_birlsfilenumber'] }
          )
        end
      end

      def should_raise_missing_uuid_error
        idme_uuid.blank? && logingov_uuid.blank?
      end

      def mvi_ids
        return @mvi_ids if @mvi_ids

        # the gcIds are a pipe-delimited concatenation of the MVI correlation IDs
        # (minus the weird "base/extension" cruft)
        gcids = safe_attr('va_eauth_gcIds')
        return {} unless gcids

        @mvi_ids = parse_string_gcids(gcids)
      end

      def safe_attr(key)
        @attributes[key] == 'NOT_FOUND' ? nil : @attributes[key]
      end

      def conditional_validate_mhv_ids
        if mhv_id_mismatch?
          if mhv_inbound_outbound
            log_message_to_sentry(
              'User attributes contain multiple distinct MHV ID values.',
              'warn',
              { mhv_ids: mhv_ids }
            )
          else
            raise SAML::UserAttributeError, SAML::UserAttributeError::ERRORS[:multiple_mhv_ids]
          end
        end
      end

      def mhv_ids
        return @mhv_ids if @mhv_ids

        uuid = safe_attr('va_eauth_mhvuuid')
        iens = safe_attr('va_eauth_mhvien')&.split(',') || []
        @mhvs_ids = iens.append(uuid).reject(&:nil?).uniq
      end

      def mhv_id_mismatch?
        mhv_ids.size > 1
      end

      def mhv_inbound_outbound
        tracker = SAMLRequestTracker.find(@tracker_uuid)
        tracker&.payload_attr(:skip_dupe) == 'mhv'
      end

      def mhv_icn_mismatch?
        mhvicn_val = safe_attr('va_eauth_mhvicn')
        icn_val = safe_attr('va_eauth_icn')
        icn_val.present? && mhvicn_val.present? && icn_val != mhvicn_val
      end

      def edipi_mismatch?
        attribute_has_multiple_values?('va_eauth_dodedipnid')
      end

      def birls_id_mismatch?
        attribute_has_multiple_values?('va_eauth_birlsfilenumber')
      end

      def corp_id_mismatch?
        attribute_has_multiple_values?('vba_corp_id')
      end

      def sec_id_mismatch?
        attribute_has_multiple_values?('va_eauth_secid')
      end

      def attribute_has_multiple_values?(attribute)
        var = safe_attr(attribute)&.split(',') || []
        var.reject(&:nil?).uniq.size > 1
      end

      def csid
        safe_attr('va_eauth_csid')&.downcase
      end
    end
  end
end
