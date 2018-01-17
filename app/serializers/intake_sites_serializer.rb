# frozen_string_literal: true
class IntakeSitesSerializer < ActiveModel::Serializer
  attribute :intake_sites

  def id
    nil
  end
end
