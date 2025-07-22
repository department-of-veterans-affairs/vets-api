# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PoaRequestFailureNotifier
    def initialize(poa_request)
      @poa_request = poa_request
    end

    def call
      raise ArgumentError, 'PoaRequest is required' unless @poa_request&.is_a?(PowerOfAttorneyRequest)

      recipient_types.each do |recipient_type|
        notification = @poa_request.notifications.create!(
          type: "enqueue_failed_for_#{recipient_type}"
        )
        PowerOfAttorneyRequestEmailJob.perform_async(notification.id)
      end
    end

    private

    def recipient_types
      [].tap do |types|
        types << :claimant if Flipper.enabled?(:ar_poa_request_claimant_failure_notification_email)
        types << :representative if Flipper.enabled?(:ar_poa_request_rep_failure_notification)
      end
    end
  end
end
