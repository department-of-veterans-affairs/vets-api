# frozen_string_literal: true

class CommunicationGroupsSerializer < ActiveModel::Serializer
  attributes :communication_groups

  def communication_groups
    object[:communication_groups]
  end

  def id
    nil
  end
end
