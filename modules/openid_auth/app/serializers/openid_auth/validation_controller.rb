# frozen_string_literal: true

module OpenidAuth
    class UserSerializer < ActiveModel::Serializer
      def uuid
        object.uid
      end

      def email
        object.email
      end

      def first_name
        object.first_name
      end

      def middle_name
        object.middle_name
      end

      def last_name
        object.last_name
      end

      def gender
        object.gender&.chars&.first&.upcase,
      end
    
      def birth_date
        object.birth_date
      end

      def last_four_ssn
        object.ssn&.chars&.last(4).join
      end

      def loa
        {
            current: object.loa,
            highest: object.loa
        }
      end
    end
  end