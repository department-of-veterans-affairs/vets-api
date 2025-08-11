# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    class ClaimLetterDocument < Common::Resource
      attribute :id, Types::String
      attribute :doc_type, Types::String
      attribute :type_description, Types::String
      attribute :received_at, Types::Date
    end
  end
end
