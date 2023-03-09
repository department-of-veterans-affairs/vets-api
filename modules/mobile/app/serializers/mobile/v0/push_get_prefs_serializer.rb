# frozen_string_literal: true

module Mobile
  module V0
    class PushGetPrefsSerializer
      include JSONAPI::Serializer

      set_type :pushGetPrefs
      attributes :preferences

      def initialize(id, preferences, options = {})
        filtered_preferences = []
        preferences.each { |pref| filtered_preferences.push(pref.except!(:auto_opt_in, :endpoint_sid)) }
        resource = PushStruct.new(id, filtered_preferences)
        super(resource, options)
      end

      PushStruct = Struct.new(:id, :preferences)
    end
  end
end
