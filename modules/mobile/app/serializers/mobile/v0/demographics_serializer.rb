# frozen_string_literal: true

module Mobile
  module V0
    class DemographicsSerializer
      include JSONAPI::Serializer

      set_type :demographics
      attributes :gender_identity, :preferred_name
      def initialize(user_id, demographics)
        resource = DemographicsStruct.new(id: user_id,
                                          gender_identity: nil,
                                          preferred_name: demographics.demographics&.preferred_name&.text)

        super(resource)
      end
    end
    DemographicsStruct = Struct.new(:id, :gender_identity, :preferred_name)
  end
end
