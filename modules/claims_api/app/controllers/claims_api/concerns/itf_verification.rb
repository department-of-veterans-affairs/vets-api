# frozen_string_literal: true

module ClaimsApi
  module ItfVerification
    extend ActiveSupport::Concern

    included do
      def itf_service
        EVSS::IntentToFile::Service.new(target_veteran)
      end
    end
  end
end
