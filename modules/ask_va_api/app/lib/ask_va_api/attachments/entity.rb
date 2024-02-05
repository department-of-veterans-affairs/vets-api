# frozen_string_literal: true

module AskVAApi
  module Attachments
    class Entity
      attr_reader :id,
                  :file_content,
                  :file_name

      def initialize(info)
        @id = info[:id]
        @file_content = info[:fileContent]
        @file_name = info[:fileName]
      end
    end
  end
end
