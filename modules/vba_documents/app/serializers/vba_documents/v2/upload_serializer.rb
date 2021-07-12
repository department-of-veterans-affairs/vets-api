# frozen_string_literal: true

#require './lib/webhooks/utilities'
module VBADocuments
  module V2
    class UploadSerializer < VBADocuments::UploadSerializer
      delegate :status, to: :object

      attribute :observers, if: :observing

      @observers

      def attributes(fields)
        attrs = super
        attrs.delete(:location)
        attrs
      end

      def observing
        @observers = WebhookSubscription.get_observers_by_guid(api_name: 'PLAY_API',
                                                              consumer_id: object.consumer_id,
                                                              api_guid: object.guid)
        @observers.any?
      end

      def observers
        @observers
      end
    end
  end
end
