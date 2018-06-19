# frozen_string_literal: true

class ServiceAuthDetailSerializer < ActiveModel::Serializer
  attribute :policy
  attribute :policy_action
  attribute :is_authorized
  attribute :errors

  def id
    nil
  end
end
