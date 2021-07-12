# frozen_string_literal: true

#require './lib/webhooks/utilities'
module VBADocuments
  module V2
    class UploadSerializer < VBADocuments::UploadSerializer
      delegate :status, to: :object

      attribute :observers

      def attributes(fields)
        attrs = super
        attrs.delete(:location)
        attrs
      end

      def observers
        WebhookSubscription.get_observers_by_guid(api_name: 'PLAY_API',
                                                  consumer_id: object.consumer_id,
                                                  api_guid: object.guid)
      end
    end
  end
end
