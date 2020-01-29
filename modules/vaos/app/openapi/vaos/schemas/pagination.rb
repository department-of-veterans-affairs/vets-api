# frozen_string_literal: true

module VAOS
  module Schemas
    class Pagination
      include Swagger::Blocks

      swagger_schema :Pagination do
        key :required, [:pagination]
        property :pagination, type: :object do
          key :required, %i[current_page per_page total_pages total_entries]
          property :current_page, type: :integer, example: 2
          property :per_page, type: :integer, example: 10
          property :total_pages, type: :integer, example: 4
          property :total_entries, type: :integer, example: 39
        end
      end
    end
  end
end
