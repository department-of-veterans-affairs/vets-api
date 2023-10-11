# frozen_string_literal: true

module AskVAApi
  module Provinces
    class Serializer < ActiveModel::Serializer
      include JSONAPI::Serializer
      set_type :provinces

      attributes :name, :abv
    end
  end
end
