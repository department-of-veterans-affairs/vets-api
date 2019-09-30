# frozen_string_literal: true

require 'saml/user_attributes/base'
require 'sentry_logging'

module SAML
  module UserAttributes
    class IdMe < Base
      include SentryLogging
      IDME_SERIALIZABLE_ATTRIBUTES = %i[first_name middle_name last_name zip gender ssn birth_date].freeze

      def first_name
        attributes['fname']
      end

      def middle_name
        attributes['mname']
      end

      def last_name
        attributes['lname']
      end

      def zip
        attributes['zip']
      end

      def gender
        attributes['gender']&.chars&.first&.upcase
      end

      def ssn
        attributes['social']&.delete('-')
      end

      def birth_date
        attributes['birth_date']
      end

      def mhv_icn
        existing_user_identity.mhv_icn if existing_user_identity? && authn_context == 'myhealthevet_loa3'
      end

      def mhv_correlation_id
        existing_user_identity.mhv_correlation_id if existing_user_identity? && authn_context == 'myhealthevet_loa3'
      end

      def mhv_account_type
        existing_user_identity.mhv_account_type if existing_user_identity? && authn_context == 'myhealthevet_loa3'
      end

      def dslogon_edipi
        existing_user_identity.dslogon_edipi if existing_user_identity? && authn_context == 'dslogon_loa3'
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
        IDME_SERIALIZABLE_ATTRIBUTES + REQUIRED_ATTRIBUTES + mergable_identity_attributes
      end

      def mergable_identity_attributes
        case authn_context
        when 'myhealthevet_loa3'
          %i[mhv_icn mhv_account_type mhv_correlation_id sign_in]
        when 'dslogon_loa3'
          %i[dslogon_edipi sign_in]
        else
          %i[sign_in]
        end
      end

      def loa_current
        @loa_current ||=
          if authn_context.include?('multifactor')
            existing_user_identity.loa.fetch(:current, 1).to_i
          else
            SAML::User::AUTHN_CONTEXTS.fetch(authn_context).fetch(:loa_current, 1).to_i
          end
      rescue NoMethodError, KeyError => e
        @warnings << "loa_current error: #{e.message}"
        @loa_current = 1 # default to something safe until we can research this
      end

      def loa_highest
        loa_highest = idme_loa || loa_current
        [loa_current, loa_highest].max
      end
    end
  end
end
