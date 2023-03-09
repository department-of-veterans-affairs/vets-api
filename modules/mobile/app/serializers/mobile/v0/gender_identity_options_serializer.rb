# frozen_string_literal: true

require 'jsonapi/serializer'

module Mobile
  module V0
    class GenderIdentityOptionsSerializer
      include JSONAPI::Serializer

      set_type :GenderIdentityOptions
      attributes :options

      def initialize(user_id, options)
        resource = GenderIdentityOptionsStruct.new(user_id, options)
        super(resource, options)
      end
    end

    GenderIdentityOptionsStruct = Struct.new(:id, :options)
  end
end
