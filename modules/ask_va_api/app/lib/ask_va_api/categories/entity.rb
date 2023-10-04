# frozen_string_literal: true

module AskVAApi
  module Categories
    class Entity
      attr_reader :id,
                  :name

      def initialize(info)
        @id = info[:id]
        @name = info[:value]
      end
    end
  end
end
