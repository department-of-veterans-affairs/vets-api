# frozen_string_literal: true

module AskVAApi
  module Categories
    class Serializer < ActiveModel::Serializer
      include JSONAPI::Serializer
      set_type :categories

      attributes :name
    end
  end
end
