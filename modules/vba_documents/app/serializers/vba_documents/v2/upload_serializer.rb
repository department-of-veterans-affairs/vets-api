# frozen_string_literal: true

require './lib/webhooks/utilities'
module VBADocuments
  module V2
    class UploadSerializer < VBADocuments::UploadSerializer
      delegate :status, to: :object

      attribute :observers, if: :observing

      def attributes(fields)
        attrs = super
        attrs.delete(:location) if Settings.vba_documents.v2_upload_endpoint_enabled
        attrs
      end

      def observing
        @observers = Webhooks::Subscription.get_observers_by_guid(
          api_name: Webhooks::Utilities.event_to_api_name[VBADocuments::Registrations::WEBHOOK_STATUS_CHANGE_EVENT],
          consumer_id: object.consumer_id,
          api_guid: object.guid
        )

        @observers.any?
      end

      attr_reader :observers
    end
  end
end
