# frozen_string_literal: true

module Mobile
  module V0
    class PreNeedBurialSerializer
      include JSONAPI::Serializer

      set_type :preneeds_receive_applications

      set_id :receive_application_id

      attribute :receive_application_id
      attribute :tracking_number
      attribute :return_code
      attribute :application_uuid
      attribute :return_description
      attribute :submitted_at
    end
  end
end
