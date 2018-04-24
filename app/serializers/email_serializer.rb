# frozen_string_literal: true

class EmailSerializer < ActiveModel::Serializer
  attributes :email, :effective_at

  def id
    nil
  end
end
