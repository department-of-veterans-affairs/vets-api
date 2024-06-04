# frozen_string_literal: true

module AskVAApi
  module BranchOfService
    class Entity
      attr_reader :id,
                  :code,
                  :description

      def initialize(info)
        @id = nil
        @code = info[:code]
        @description = info[:description]
      end
    end
  end
end
