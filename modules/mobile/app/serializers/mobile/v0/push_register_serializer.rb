# frozen_string_literal: true

module Mobile
  module V0
    class PushRegisterSerializer
      include JSONAPI::Serializer

      set_type :pushRegister
      attributes :endpoint_sid

      def initialize(id, endpoint_sid, options = {})
        resource = PushStruct.new(id, endpoint_sid)
        super(resource, options)
      end

      PushStruct = Struct.new(:id, :endpoint_sid)
    end
  end
end
