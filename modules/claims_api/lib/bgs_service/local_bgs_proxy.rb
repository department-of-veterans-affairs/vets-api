# frozen_string_literal: true

require 'bgs_service/local_bgs_refactored'
require 'bgs_service/local_bgs'

module ClaimsApi
  # Proxy class that switches at runtime between using `LocalBGS` and
  # `LocalBGSRefactored` depending on the value of our feature toggle.
  class LocalBGSProxy
    legacy_ancestors =
      LocalBGS.ancestors -
      LocalBGSRefactored.ancestors

    legacy_api =
      legacy_ancestors.flat_map do |ancestor|
        ancestor.instance_methods(false) - [:initialize]
      end

    refactored_ancestors =
      LocalBGSRefactored.ancestors -
      LocalBGS.ancestors

    refactored_api =
      refactored_ancestors.flat_map do |ancestor|
        ancestor.instance_methods(false) - [:initialize]
      end

    # This makes the assumption that we'll maintain compatibility for callers of
    # `LocalBGS` by considering only its public instance methods, and in
    # particular those not installed by framework-level ancestors. A "one-time"
    # check was performed to ensure that instance methods that callers invoke
    # directly are contained in `common_api` and not contained in `missing_api`.
    missing_api = legacy_api - refactored_api
    common_api = legacy_api & refactored_api

    Rails.logger.trace(
      "Comparison between LocalBGS and LocalBGSRefactored API's",
      missing_api:,
      common_api:
    )

    class << self
      delegate :breakers_service, to: :get_proxied_klass

      def get_proxied_klass
        if Flipper.enabled?(:claims_api_local_bgs_refactor)
          LocalBGSRefactored
        else
          LocalBGS
        end
      end
    end

    delegate(*common_api, to: :proxied)
    attr_reader :proxied

    def initialize(...)
      @proxied = self.class.get_proxied_klass.new(...)
    end
  end
end
