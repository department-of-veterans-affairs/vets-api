# frozen_string_literal: true

require './lib/webhooks/utilities'
module VBADocuments
  module V2
    class UploadSerializer < VBADocuments::UploadSerializer
      attr_reader :observers

      attribute :status
      attribute :location, if: proc { !Settings.vba_documents.v2_upload_endpoint_enabled } do |object, params|
        object.get_location if params[:render_location]
      rescue => e
        raise Common::Exceptions::InternalServerError, e
      end

      # does not appear to be in use, so return nil
      # the tests that check observers are pending
      attribute :observers, if: proc { |object|
        observers = Webhooks::Subscription.get_observers_by_guid(
          api_name: Webhooks::Utilities.event_to_api_name[VBADocuments::Registrations::WEBHOOK_STATUS_CHANGE_EVENT],
          consumer_id: object.consumer_id,
          api_guid: object.guid
        )

        observers.any?
      } do |_object|
        nil
      end
    end
  end
end
