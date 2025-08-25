# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PoaRequestFailureNotifier
    def initialize(poa_request)
      @poa_request = poa_request
    end

    def call(async: true)
      raise ArgumentError, 'PoaRequest is required' unless @poa_request.is_a?(PowerOfAttorneyRequest)

      recipient_types.each do |recipient_type|
        notification = @poa_request.notifications.create!(
          type: 'enqueue_failed',
          recipient_type: recipient_type.to_s
        )

        if async
          PowerOfAttorneyRequestEmailJob.perform_async(notification.id)
        else
          PowerOfAttorneyRequestEmailJob.new.perform(notification.id)
        end
      end
    end

    private

    def recipient_types
      [].tap do |types|
        types << :claimant if Flipper.enabled?(:ar_poa_request_failure_claimant_notification)
        types << :resolver if Flipper.enabled?(:ar_poa_request_failure_rep_notification)
      end
    end
  end
end
