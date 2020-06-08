# frozen_string_literal: true

class EVSSIntakeSitesSerializer < ActiveModel::Serializer
  attribute :intake_sites

  def id
    nil
  end
end
