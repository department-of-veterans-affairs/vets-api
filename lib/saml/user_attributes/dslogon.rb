# frozen_string_literal: true
require 'saml/user_attributes/base_decorator'

# TODO: remove these nocov comments when this is able to be tested.

module SAML
  module UserAttributes
    class DSLogon < BaseDecorator
      PREMIUM_LOAS = %w(2 3).freeze

      def uuid
        attributes['uuid']
      end

      def email
        attributes['email']
      end

      def dslogon_edipi
        attributes['dslogon_uuid']
      end

      def dslogon_status
        attributes['dslogon_status']
      end

      # DS Logon will sometimes return a gender with literal 'unknown'
      def gender
        gender = attributes['dslogon_gender']&.chars&.first&.upcase
        %w(M F).include?(gender) ? gender : nil
      end

      def dslogon_deceased
        attributes['dslogon_deceased']
      end

      def birth_date
        attributes['dslogon_birth_date']
      end

      def first_name
        attributes['dslogon_fname']
      end

      def middle_name
        attributes['dslogon_mname']
      end

      def last_name
        attributes['dslogon_lname']
      end

      def dslogon_idtype
        attributes['dslogon_idtype']
      end

      def ssn
        attributes['dslogon_idvalue']
      end

      def dslogon_assurance
        attributes['dslogon_assurance']
      end

      def loa
        { current: loa_current, highest: loa_highest }
      end

      def multifactor
        attributes['multifactor']
      end

      # The first ones are values needed to query MVI
      # The second ones are additional values that should override MVI (EDIPI or match)
      # In short we might find that a user has inconsistencies in MVI with the EDIPI provided.
      # The last part are ID.me specific attributes used by vets.gov
      def serializable_attributes
        %i(
          first_name middle_name last_name email gender ssn birth_date
          dslogon_edipi dslogon_status dslogon_deceased
          uuid multifactor loa
        )
      end

      # This value comes from IDme, it will be 3 if FICAM LOA3, null otherwise.
      def idme_loa
        attributes['level_of_assurance']&.to_i
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
