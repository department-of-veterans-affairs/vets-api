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

      def existing_user_identity
        @existing_user_identity ||= UserIdentity.find(uuid)
      end

      def loa_current
        if authn_context.include?('multifactor')
          existing_user_identity.loa.fetch(:current, 1).to_i
        else
          SAML::User::AUTHN_CONTEXTS.fetch(authn_context).fetch(:loa_current, 1).to_i
        end
      rescue NoMethodError, KeyError => error
        log_loa_current_message_once(error)
        1 # default to something safe until we can research this
      end

      def loa_highest
        loa_highest = idme_loa || loa_current
        [loa_current, loa_highest].max
      end

      def log_loa_current_message_once(error)
        return if @logged_loa_current_message
        binding.pry
        extra_context = {
          uuid: attributes['uuid'],
          idme_level_of_assurance: attributes['level_of_assurance'],
          authn_context: authn_context
        }
        log_message_to_sentry("loa_current error: #{error.message}", :info, extra_context)
        @logged_loa_current_message = true
      end
    end
  end
end
