# frozen_string_literal: true
module EVSS
  module EVSSCommon
    class Service < EVSS::Service
      configuration EVSS::EVSSCommon::Configuration

      def create_user_account
        perform(
          :post,
          'persistentPropertiesService/11.0/createUserAccount',
          nil
        )
      end
    end
  end
end
