# frozen_string_literal: true

module AskVAApi
  module SubTopics
    class Entity
      attr_reader :id,
                  :name

      def initialize(info)
        @id = info[:id]
        @name = info[:subtopic]
      end
    end
  end
end
