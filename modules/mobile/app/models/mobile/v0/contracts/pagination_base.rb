# frozen_string_literal: true

module Mobile
  module V0
    module Contracts
      class PaginationBase < Base
        def self.params(*external_schemas, &block)
          schemas = [Schemas::PaginationSchema, *external_schemas].uniq
          super(*schemas, &block)
        end

        params
      end
    end
  end
end
