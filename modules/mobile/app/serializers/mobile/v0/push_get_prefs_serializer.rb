# frozen_string_literal: true

module Mobile
  module V0
    class PushGetPrefsSerializer
      include FastJsonapi::ObjectSerializer

      set_type :pushGetPrefs
      attributes :preferences

      def initialize(id, preferences, options = {})
        resource = PushStruct.new(id, preferences)
        super(resource, options)
      end

      PushStruct = Struct.new(:id, :preferences)
    end
  end
end
