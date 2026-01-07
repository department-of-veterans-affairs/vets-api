# frozen_string_literal: true

module MyHealth
  module V2
    class DrugSheetSerializer
      include JSONAPI::Serializer

      set_id do |object|
        Digest::SHA256.hexdigest(object.html[:html].to_s)
      end

      attributes :html do |object|
        object.html[:html]
      end
    end
  end
end
