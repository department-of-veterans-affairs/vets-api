# frozen_string_literal: true

class UserActionSerializer
  include JSONAPI::Serializer

  attribute :user_action_event_id, :status, :subject_user_verification_id, :acting_ip_address,
            :acting_user_agent, :created_at, :updated_at, :acting_user_verification_id

  belongs_to :user_action_event
end
