# frozen_string_literal: true

module AskVAApi
  module Correspondences
    class Serializer < ActiveModel::Serializer
      include JSONAPI::Serializer
      set_type :correspondence

      attributes :message_type,
                 :modified_on,
                 :status_reason,
                 :description,
                 :enable_reply,
                 :attachments
    end
  end
end
