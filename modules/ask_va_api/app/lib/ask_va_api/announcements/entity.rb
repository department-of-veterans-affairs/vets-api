# frozen_string_literal: true

module AskVAApi
  module Announcements
    class Entity
      attr_reader :id,
                  :text,
                  :start_date,
                  :end_date,
                  :is_portal

      def initialize(info)
        @id = info[:id]
        @text = info[:Text]
        @start_date = info[:StartDate]
        @end_date = info[:EndDate]
        @is_portal = info[:IsPortal]
      end
    end
  end
end
