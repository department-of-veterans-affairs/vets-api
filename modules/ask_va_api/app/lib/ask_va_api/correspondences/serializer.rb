# frozen_string_literal: true

module AskVAApi
  module Correspondences
    class Serializer < ActiveModel::Serializer
      include JSONAPI::Serializer
      set_type :correspondence

      attributes :inquiry_id,
                 :message,
                 :modified_on,
                 :status_reason,
                 :description,
                 :enable_reply,
                 :attachment_names
    end
  end
end
