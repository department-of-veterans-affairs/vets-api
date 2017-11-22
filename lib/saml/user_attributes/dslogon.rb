# frozen_string_literal: true
require 'saml/user_attributes/base'

module SAML
  module UserAttributes
    class DSLogon < Base
      PREMIUM_LOAS = %w(2 3).freeze
      DSLOGON_SERIALIZABLE_ATTRIBUTES = %i(first_name middle_name last_name gender ssn birth_date
                                           dslogon_edipi dslogon_status dslogon_deceased).freeze

      def first_name
        attributes['dslogon_fname']
      end

      def middle_name
        attributes['dslogon_mname']
      end

      def last_name
        attributes['dslogon_lname']
      end

      # DS Logon will sometimes return a gender with literal 'unknown'
      def gender
        gender = attributes['dslogon_gender']&.chars&.first&.upcase
        %w(M F).include?(gender) ? gender : nil
      end

      def ssn
        attributes['dslogon_idvalue']
      end

      def birth_date
        attributes['dslogon_birth_date']
      end

      def dslogon_edipi
        attributes['dslogon_uuid']
      end

      def dslogon_status
        attributes['dslogon_status']
      end

      def dslogon_deceased
        attributes['dslogon_deceased']
      end

      def dslogon_idtype
        attributes['dslogon_idtype']
      end

      def dslogon_assurance
        attributes['dslogon_assurance']
      end

      private

      # These methods are required to be implemented on each child class

      def serializable_attributes
        DSLOGON_SERIALIZABLE_ATTRIBUTES + REQUIRED_ATTRIBUTES
      end

      # if the dslogon_assurance PREMIUM, otherwise 1
      # NOTE: idme will always return highest attained, but for iniital non-premium this will always be 1
      # the leveling up verification step invoked by F/E will correctly capture as LOA3.
      def loa_current
        PREMIUM_LOAS.include?(dslogon_assurance) ? 3 : 1
      end

      # This is "highest attained" via idp
      # if the dslogon_assurance PREMIUM or IDME = 3,
      def loa_highest
        PREMIUM_LOAS.include?(dslogon_assurance) ? 3 : (idme_loa || loa_current)
      end
    end
  end
end
