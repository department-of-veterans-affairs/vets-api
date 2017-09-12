# frozen_string_literal: true
require 'saml/user_attributes/base_decorator'

# TODO: remove these nocov comments when this is able to be tested.
#:nocov:
module SAML
  module UserAttributes
    class MHV < BaseDecorator
      def mhv_icn
        attributes['mhv_icn']
      end

      # NOTE: this is derived from mhv_profile which is a complex JSON object, see above
      def account_type
        mhv_profile['accountType']
      end

      # NOTE: this is derived from mhv_profile which is a complex JSON object, see above
      # QUESTION: Why is this premium user only listed to have Blue Button and not Rx or SM?
      def available_services
        mhv_profile['availableServices']
      end

      # NOTE: this is the same thing as mhv_correlation_id it should supercede any mhv
      # mhv correlation id that is returned by MVI
      def uuid
        attributes['mhv_uuid']
      end

      # NOTE: This attribute is originated by id.me
      def email
        attributes['email']
      end

      # NOTE: This attribute is originated by id.me
      def multifactor
        attributes['multifactor']
      end

      # NOTE: See comments for loa_current and loa_highest below
      def loa
        { current: loa_current, highest: loa_highest }
      end

      private

      # NOTE: email, uuid, loa are derived values, all others originate from MHV
      # For now we will probably not use available services, mhv profile is unnecessary
      # once we have the base components
      def serializable_attributes
        %i(mhv_icn email uuid loa multifactor)
      end

      # if the account type is premium then the user has identity proofed with MHV and we trust it
      def loa_current
        account_type == 'Premium' ? 2 : 1
      end

      # if the account type is premium there is no option to FICAM level up the account, so the highest is
      # the current level of 2. If however the user is Basic or Advanced, they should have the option
      # to level up their account using ID.me similar to other ID.me login users
      def loa_highest
        account_type == 'Premium' ? 2 : 3
      end

      # NOTE: this will always be a JSON object, see above
      def mhv_profile
        JSON.parse(attributes['mhv_profile'])
      end
    end
  end
end
#:nocov:
