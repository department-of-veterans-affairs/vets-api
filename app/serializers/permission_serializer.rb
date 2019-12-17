# frozen_string_literal: true

class PermissionSerializer < ActiveModel::Serializer
  attribute :permission_type
  attribute :permission_value

  def id
    nil
  end
end
