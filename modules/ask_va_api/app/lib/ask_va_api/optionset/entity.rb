# frozen_string_literal: true

module AskVAApi
  module Optionset
    class Entity
      attr_reader :id,
                  :name

      def initialize(info)
        @id = info[:id]
        @name = info[:name]
      end
    end
  end
end
