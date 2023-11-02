# frozen_string_literal: true

module AskVAApi
  module Correspondences
    class Serializer < ActiveModel::Serializer
      include JSONAPI::Serializer
      set_type :correspondence

      attributes :inquiry_number,
                 :correspondence
    end
  end
end
