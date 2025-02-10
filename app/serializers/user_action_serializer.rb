# frozen_string_literal: true

class UserActionSerializer
  include JSONAPI::Serializer

  attribute :user_action_event, :status, :subject_user_verification, :acting_ip_address,
            :acting_user_agent, :created_at, :updated_at, :acting_user_verification

  belongs_to :user_action_events
  belongs_to :acting_user_verification
  belongs_to :subject_user_verification
end
