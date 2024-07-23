# frozen_string_literal: true

module AskVAApi
  module Announcements
    class Serializer
      include JSONAPI::Serializer
      set_type :announcements

      attributes :text, :start_date, :end_date, :is_portal
    end
  end
end
