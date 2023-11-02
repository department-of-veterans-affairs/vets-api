# frozen_string_literal: true

module AskVAApi
  module SubTopics
    class Serializer < ActiveModel::Serializer
      include JSONAPI::Serializer
      set_type :subtopics

      attributes :name
    end
  end
end
