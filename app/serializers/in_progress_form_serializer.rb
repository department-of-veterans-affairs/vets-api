# frozen_string_literal: true

require 'fast_jsonapi'

class InProgressFormSerializer
  include FastJsonapi::ObjectSerializer

  # we want camelized top-level keys [1], but we don't fast_jsonapi to transform
  # any nested keys (we want them exactly as the front-end left them) [2]

  # by default fast_jsonapi underscores keys.
  # "" is not a valid option. see mapping:
  #   https://github.com/Netflix/fast_jsonapi/blob/master/lib/fast_jsonapi/object_serializer.rb#L140
  # but guarantees that the hash keys won't be transformed
  set_key_transform '' # [2]

  # [1]
  attribute(:formId, &:form_id)
  attribute(:createdAt, &:created_at)
  attribute(:updatedAt, &:updated_at)
  attribute :metadata
end
