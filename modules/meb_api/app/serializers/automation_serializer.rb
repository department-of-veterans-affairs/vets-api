# frozen_string_literal: true

class AutomationSerializer < ActiveModel::Serializer
  attribute :claimant
  attribute :service_data

  def id
    nil
  end
end
