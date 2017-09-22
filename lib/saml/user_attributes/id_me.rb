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

      private

      def serializable_attributes
        %i(first_name middle_name last_name zip email gender ssn birth_date uuid)
      end
    end
  end
end
