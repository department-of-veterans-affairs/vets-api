# frozen_string_literal: true
class SessionSerializer < ActiveModel::Serializer
  attributes :level

  def id
    nil
  end
end
