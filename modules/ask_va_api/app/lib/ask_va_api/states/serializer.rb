# frozen_string_literal: true

module AskVAApi
  module States
    class Serializer < ActiveModel::Serializer
      include JSONAPI::Serializer
      set_type :states

      attributes :name, :code
    end
  end
end
