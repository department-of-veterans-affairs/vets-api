# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    class ClaimEventTimeline < Common::Resource
      attribute :activity_description, Types::String.optional.default(nil)
      attribute :can_upload_file, Types::Bool.optional.default(nil)
      attribute :closed_date, Types::Date.optional.default(nil)
      attribute :date, Types::Date.optional.default(nil)
      attribute :description, Types::String.optional.default(nil)
      attribute :display_name, Types::String.optional.default(nil)
      attribute :document_id, Types::String.optional.default(nil)
      attribute :document_type, Types::String.optional.default(nil)
      attribute :documents, Types::Array.of(ClaimDocument).optional.default(nil)
      attribute :file_type, Types::String.optional.default(nil)
      attribute :filename, Types::String.optional.default(nil)
      attribute :friendly_name, Types::String.optional.default(nil)
      attribute :is_dbq, Types::Bool.optional.default(nil)
      attribute :is_proper_noun, Types::Bool.optional.default(nil)
      attribute :is_sensitive, Types::Bool.optional.default(nil)
      attribute :long_description, Types::Hash.optional.default(nil)
      attribute :next_steps, Types::Hash.optional.default(nil)
      attribute :no_action_needed, Types::Bool.optional.default(nil)
      attribute :no_provide_prefix, Types::Bool.optional.default(nil)
      attribute :opened_date, Types::Date.optional.default(nil)
      attribute :overdue, Types::Bool.optional.default(nil)
      attribute :received_date, Types::Date.optional.default(nil)
      attribute :requested_date, Types::Date.optional.default(nil)
      attribute :short_description, Types::String.optional.default(nil)
      attribute :status, Types::String.optional.default(nil)
      attribute :support_aliases, Types::Array.of(Types::String).optional.default(nil)
      attribute :suspense_date, Types::Date.optional.default(nil)
      attribute :tracked_item_id, Types::Integer.optional.default(nil)
      attribute :type, Types::String
      attribute :upload_date, Types::Date.optional.default(nil)
      attribute :uploaded, Types::Bool.optional.default(nil)
      attribute :uploads_allowed, Types::Bool.optional.default(nil)
    end
  end
end
