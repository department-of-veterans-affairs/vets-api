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

      private

      # These methods are required to be implemented on each child class

      def serializable_attributes
        IDME_SERIALIZABLE_ATTRIBUTES + REQUIRED_ATTRIBUTES
      end

      def loa_current
        LOA::MAPPING[real_authn_context]
      end

      def loa_highest
        loa_highest = idme_loa || loa_current
        [loa_current, loa_highest].max
      rescue ArgumentError => exception
        extra_context = {
          uuid: attributes['uuid'],
          idme_level_of_assurance: attributes['level_of_assurance'],
          loa_current: loa_current,
          loa_highest: loa_highest,
          real_authn_context: real_authn_context
        }
        log_exception_to_sentry(exception, extra_context)
        loa_current || 1 # default to something safe until we can research this
      end
    end
  end
end
