# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    class ClaimEventTimeline < Common::Resource
      attribute :type, Types::String
      attribute :tracked_item_id, Types::Integer.optional
      attribute :description, Types::String.optional
      attribute :display_name, Types::String.optional
      attribute :overdue, Types::Bool.optional
      attribute :status, Types::String.optional
      attribute :uploaded, Types::Bool.optional
      attribute :uploads_allowed, Types::Bool.optional
      attribute :opened_date, Types::Date.optional
      attribute :requested_date, Types::Date.optional
      attribute :received_date, Types::Date.optional
      attribute :closed_date, Types::Date.optional
      attribute :suspense_date, Types::Date.optional
      attribute :documents, Types::Array.of(ClaimDocument).optional
      attribute :upload_date, Types::Date.optional
      attribute :date, Types::Date.optional
      attribute :file_type, Types::String.optional
      attribute :document_type, Types::String.optional
      attribute :filename, Types::String.optional
    end
  end
end
