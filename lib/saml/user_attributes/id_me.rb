# frozen_string_literal: true

require 'saml/user_attributes/base'
require 'sentry_logging'

module SAML
  module UserAttributes
    class IdMe < Base
      include SentryLogging
      IDME_SERIALIZABLE_ATTRIBUTES = %i[first_name middle_name last_name zip gender ssn birth_date].freeze
      LOA_MAPPING = {
        'http://idmanagement.gov/ns/assurance/loa/1/vets': 1,
        'http://idmanagement.gov/ns/assurance/loa/3/vets': 3,
        'myhealthevet_loa3': 3, # This is ID.me
        'dslogon_loa3': 3, # This is ID.me
        # 'myhealthevet_multifactor' could map to either ONE or THREE, and is ID.me
        # 'dslogon_multifactor' could map to either ONE or THREE, and is ID.me
        # FIXME: this is still going to cause loa_current to be nil for MFA, TODO: move merging here from sso_service
      }.with_indifferent_access.freeze

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

      private

      # These methods are required to be implemented on each child class

      def serializable_attributes
        IDME_SERIALIZABLE_ATTRIBUTES + REQUIRED_ATTRIBUTES
      end

      def loa_current
        LOA_MAPPING.fetch(real_authn_context)
      rescue KeyError
        log_loa_current_message_once
        1 # default to something safe until we can research this
      end

      def loa_highest
        loa_highest = idme_loa || loa_current
        [loa_current, loa_highest].max
      end

      def log_loa_current_message_once
        return if @logged_loa_current_message
        extra_context = {
          uuid: attributes['uuid'],
          idme_level_of_assurance: attributes['level_of_assurance'],
          real_authn_context: real_authn_context
        }
        log_message_to_sentry('loa_current is mapping to nil', :info, extra_context)
        @logged_loa_current_message = true
      end
    end
  end
end
