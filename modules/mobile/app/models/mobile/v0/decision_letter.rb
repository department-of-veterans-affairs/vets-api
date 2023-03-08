# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    class DecisionLetter < Common::Resource
      attribute :document_id, Types::String
      attribute :series_id, Types::String.optional
      attribute :version, Types::String.optional
      attribute :type_description, Types::String.optional
      attribute :type_id, Types::String.optional
      attribute :doc_type, Types::String.optional
      attribute :subject, Types::String.optional
      attribute :received_at, Types::DateTime
      attribute :source, Types::String.optional
      attribute :mime_type, Types::String.optional
      attribute :alt_doc_types, Types::String.optional
      attribute :restricted, Types::Bool
      attribute :upload_date, Types::DateTime.optional
    end
  end
end
