# frozen_string_literal: true

require 'digest'

module MyHealth
  module V1
    class PrescriptionDocumentationSerializer
      include JSONAPI::Serializer

      set_id { '' }

      attributes :html do |object|
        object.html[:html]
      end
    end
  end
end
