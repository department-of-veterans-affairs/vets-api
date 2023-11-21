# frozen_string_literal: true

module AskVAApi
  module Topics
    class Serializer < ActiveModel::Serializer
      include JSONAPI::Serializer
      set_type :topics

      attributes :name
    end
  end
end
