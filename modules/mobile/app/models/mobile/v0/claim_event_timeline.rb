# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    class ClaimEventTimeline < Common::Resource
      attribute :type, Types::String
      attribute :tracked_item_id, Types::Integer.optional.default(nil)
      attribute :description, Types::String.optional.default(nil)
      attribute :display_name, Types::String.optional.default(nil)
      attribute :overdue, Types::Bool.optional.default(nil)
      attribute :status, Types::String.optional.default(nil)
      attribute :uploaded, Types::Bool.optional.default(nil)
      attribute :uploads_allowed, Types::Bool.optional.default(nil)
      attribute :opened_date, Types::Date.optional.default(nil)
      attribute :requested_date, Types::Date.optional.default(nil)
      attribute :received_date, Types::Date.optional.default(nil)
      attribute :closed_date, Types::Date.optional.default(nil)
      attribute :suspense_date, Types::Date.optional.default(nil)
      attribute :documents, Types::Array.of(ClaimDocument).optional.default(nil)
      attribute :upload_date, Types::Date.optional.default(nil)
      attribute :date, Types::Date.optional.default(nil)
      attribute :file_type, Types::String.optional.default(nil)
      attribute :document_type, Types::String.optional.default(nil)
      attribute :filename, Types::String.optional.default(nil)
      attribute :document_id, Types::String.optional.default(nil)
    end
  end
end
