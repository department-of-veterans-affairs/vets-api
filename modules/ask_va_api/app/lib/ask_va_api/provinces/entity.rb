# frozen_string_literal: true

module AskVAApi
  module Provinces
    class Entity
      attr_reader :id,
                  :name,
                  :abv

      def initialize(info)
        @id = info[:id]
        @name = info[:name]
        @abv = info[:abbreviation]
      end
    end
  end
end
