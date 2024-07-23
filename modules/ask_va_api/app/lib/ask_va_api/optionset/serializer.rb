# frozen_string_literal: true

module AskVAApi
  module Optionset
    class Serializer
      include JSONAPI::Serializer
      set_type :optionsets

      attributes :name
    end
  end
end
