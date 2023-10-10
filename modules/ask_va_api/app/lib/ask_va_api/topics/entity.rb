# frozen_string_literal: true

module AskVAApi
  module Topics
    class Entity
      attr_reader :id,
                  :name

      def initialize(info)
        @id = info[:id]
        @name = info[:topic]
      end
    end
  end
end
