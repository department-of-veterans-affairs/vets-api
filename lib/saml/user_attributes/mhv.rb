# frozen_string_literal: true

require 'saml/user_attributes/base'

module SAML
  module UserAttributes
    class MHV < Base
      PREMIUM_LOAS = %w[Premium].freeze
      MHV_SERIALIZABLE_ATTRIBUTES = %i[mhv_icn mhv_correlation_id].freeze

      def mhv_icn
        attributes['mhv_icn']
      end

      def account_type
        mhv_profile['accountType']
      end

      def available_services
        mhv_profile['availableServices']
      end

      def mhv_correlation_id
        attributes['mhv_uuid']
      end

      private

      # These methods are required to be implemented on each child class

      # NOTE: this will always be a JSON object, see above
      def mhv_profile
        JSON.parse(attributes['mhv_profile'])
      end

      def serializable_attributes
        MHV_SERIALIZABLE_ATTRIBUTES + REQUIRED_ATTRIBUTES
      end

      # if the account_type PREMIUM, otherwise 1
      # NOTE: idme will always return highest attained, but for iniital non-premium this will always be 1
      # the leveling up verification step invoked by F/E will correctly capture as LOA3.
      def loa_current
        PREMIUM_LOAS.include?(account_type) ? 3 : 1
      end

      # This is "highest attained" via idp
      # if the account_type PREMIUM or IDME = 3,
      def loa_highest
        PREMIUM_LOAS.include?(account_type) ? 3 : (idme_loa || loa_current)
      end
    end
  end
end
