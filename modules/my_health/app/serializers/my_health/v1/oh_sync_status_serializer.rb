# frozen_string_literal: true

module MyHealth
  module V1
    class OhSyncStatusSerializer
      include JSONAPI::Serializer

      set_type :oh_sync_status
      set_id { '' }

      attribute :status do |object|
        object[:status]
      end

      attribute :sync_complete do |object|
        object[:sync_complete]
      end

      attribute :error do |object|
        object[:error]
      end
    end
  end
end
