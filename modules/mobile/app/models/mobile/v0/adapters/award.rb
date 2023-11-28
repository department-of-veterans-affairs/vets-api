# frozen_string_literal: true

module Mobile
  module V0
    module Adapters
      class Award
        def parse(list)
          list
            .map { |entry| Mobile::V0::Award.new(entry) }
        end
      end
    end
  end
end
