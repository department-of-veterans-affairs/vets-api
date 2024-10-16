# frozen_string_literal: true

class OnsiteNotificationSerializer
  include JSONAPI::Serializer

  attributes :template_id, :va_profile_id, :dismissed, :created_at, :updated_at
end
