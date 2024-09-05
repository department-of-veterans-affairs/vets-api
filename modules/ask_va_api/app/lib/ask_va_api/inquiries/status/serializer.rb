# frozen_string_literal: true

module AskVAApi
  module Inquiries
    module Status
      class Serializer
        include JSONAPI::Serializer
        set_type :inquiry_status

        attributes :status
      end
    end
  end
end
