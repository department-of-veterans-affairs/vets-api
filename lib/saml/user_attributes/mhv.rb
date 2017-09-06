# frozen_string_literal: true
require 'saml/user_attributes/base_decorator'

# TODO: remove these nocov comments when this is able to be tested.
#:nocov:
module SAML
  module UserAttributes
    class MHV < BaseDecorator
      def mhv_icn
        attributes['mhv_icn']&.first
      end

      def mhv_profile
        JSON.parse(attributes['mhv_profile']&.first)
      end

      def account_type
        mhv_profile['accountType']
      end

      def available_services
        mhv_profile['availableServices']
      end

      def mhv_uuid
        attributes['mhv_uuid']
      end

      private

      def serializable_attributes
        %i(mhv_icn mhv_profile account_type available_services mhv_uuid)
      end
    end
  end
end
#:nocov:
