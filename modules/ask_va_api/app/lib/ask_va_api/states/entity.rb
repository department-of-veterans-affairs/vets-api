# frozen_string_literal: true

module AskVAApi
  module States
    class Entity
      attr_reader :id,
                  :name,
                  :code

      def initialize(info)
        @id = info[:id]
        @name = info[:stateName]
        @code = info[:code]
      end
    end
  end
end
