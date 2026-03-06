# frozen_string_literal: true

module Mobile
  module V0
    class OhSyncStatusSerializer
      include JSONAPI::Serializer

      set_type :oh_sync_status
      attributes :status, :sync_complete, :error

      def initialize(id, sync_status_data, options = {})
        resource = OhSyncStatusStruct.new(
          id,
          sync_status_data[:status],
          sync_status_data[:sync_complete],
          sync_status_data[:error]
        )
        super(resource, options)
      end
    end

    OhSyncStatusStruct = Struct.new(:id, :status, :sync_complete, :error)
  end
end
