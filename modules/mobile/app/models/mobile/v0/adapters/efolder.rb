# frozen_string_literal: true

module Mobile
  module V0
    module Adapters
      class Efolder
        def self.parse(documents)
          documents.map do |document|
            Mobile::V0::Efolder.new(
              id: document[:document_id],
              doc_type: document[:doc_type],
              type_description: document[:type_description],
              received_at: document[:received_at]
            )
          end
        end
      end
    end
  end
end
