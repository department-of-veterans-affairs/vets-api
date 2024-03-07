# frozen_string_literal: true

module AskVAApi
  module Attachments
    class Entity
      attr_reader :id,
                  :file_content,
                  :file_name

      def initialize(info)
        @id = info[:Id]
        @file_content = info[:FileContent]
        @file_name = info[:FileName]
      end
    end
  end
end
