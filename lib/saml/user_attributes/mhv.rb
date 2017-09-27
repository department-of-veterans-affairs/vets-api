# frozen_string_literal: true
require 'saml/user_attributes/base_decorator'

# TODO: remove these nocov comments when this is able to be tested.
# :nocov:
module SAML
  module UserAttributes
    class MHV < BaseDecorator
      PREMIUM_LOAS = %w(Premium).freeze

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
      def mhv_correlation_id
        attributes['mhv_uuid']
      end

      def uuid
        attributes['uuid']
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

      # NOTE: email, uuid, loa are derived values, all others originate from MHV
      # For now we will probably not use available services, mhv profile is unnecessary
      # once we have the base components
      def serializable_attributes
        %i(mhv_icn email uuid loa multifactor)
      end

      # NOTE: this will always be a JSON object, see above
      def mhv_profile
        JSON.parse(attributes['mhv_profile'])
      end

      def idme_loa
        attributes['level_of_assurance']&.to_i
      end

      # if the account_type PREMIUM or IDME = 3, otherwise 1
      def loa_current
        PREMIUM_LOAS.include?(account_type) ? 3 : (idme_loa || 1)
      end

      # This is "highest attained" via idp
      # if the account_type PREMIUM or IDME = 3,
      def loa_highest
        PREMIUM_LOAS.include?(account_type) ? 3 : (idme_loa || loa_current)
      end

      def loa_highest_available
        3
      end
    end
  end
end
# :nocov:
