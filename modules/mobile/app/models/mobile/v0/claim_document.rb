# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    class ClaimDocument < Common::Resource
      attribute :tracked_item_id, Types::Integer
      attribute :file_type, Types::String
      attribute :document_type, Types::Nil
      attribute :filename, Types::String
      attribute :upload_date, Types::Date
      attribute :document_id, Types::String
    end
  end
end
