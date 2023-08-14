# frozen_string_literal: true

module AskVAApi
  module Replies
    class Serializer < ActiveModel::Serializer
      include JSONAPI::Serializer
      set_type :reply

      attributes :inquiry_number,
                 :reply
    end
  end
end
