# frozen_string_literal: true
require 'saml/user_attributes/base_decorator'

module SAML
  module UserAttributes
    class IdMe < BaseDecorator
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

      def email
        attributes['email']
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

      def uuid
        attributes['uuid']
      end

      def loa
        { current: loa_current, highest: loa_highest, highest_available: loa_highest_available }
      end

      private

      def serializable_attributes
        %i(first_name middle_name last_name zip email gender ssn birth_date uuid loa)
      end

      def loa_current
        @raw_loa ||= REXML::XPath.first(saml_response.decrypted_document, '//saml:AuthnContextClassRef')&.text
        LOA::MAPPING[@raw_loa]
      end

      def loa_highest
        saml_loa = attributes['level_of_assurance']&.to_i
        Rails.logger.warn 'LOA.highest is nil!' if saml_loa.nil?
        loa_highest = saml_loa || loa_current
        Rails.logger.warn 'LOA.highest is less than LOA.current' if loa_highest < loa_current
        [loa_current, loa_highest].max
      end

      def loa_highest_available
        3
      end
    end
  end
end
