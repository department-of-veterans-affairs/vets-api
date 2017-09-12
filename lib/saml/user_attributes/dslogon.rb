# frozen_string_literal: true
require 'saml/user_attributes/base_decorator'

# TODO: remove these nocov comments when this is able to be tested.
#:nocov:
module SAML
  module UserAttributes
    class DSLogon < BaseDecorator
      PREMIUM_ASSURANCE_LEVELS = %w(2 3)

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

      def gender
        attributes['dslogon_gender']&.chars&.first&.upcase
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

      private

      # The first ones are values needed to query MVI
      # The second ones are additional values that should override MVI (EDIPI or match)
      # In short we might find that a user has inconsistencies in MVI with the EDIPI provided.
      # The last part are ID.me specific attributes used by vets.gov
      def serializable_attributes
        %i(first_name middle_name last_name email gender ssn birth_date)
        + %i(dslogon_edipi dslogon_status dslogon_deceased)
        + %i(uuid multifactor loa)
      end

      # if the account has dslogon assurance 2 or 3 then the user has identity proofed
      def loa_current
        PREMIUM_ASSURANCE_LEVELS.include?(dslogon_assurance) ? 2 : 1
      end

      # if the account has dslogon assurance 2 or 3 there is no option to FICAM level up the account,
      # so the highest is the current level of 2. If however the user is Basic or Advanced, they
      # should have the option to level up their account using ID.me similar to other ID.me login users
      def loa_highest
        PREMIUM_ASSURANCE_LEVELS.include?(dslogon_assurance) ? 2 : 3
      end
    end
  end
end
#:nocov:
