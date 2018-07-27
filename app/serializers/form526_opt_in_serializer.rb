# frozen_string_literal: true

class Form526OptInSerializer < ActiveModel::Serializer
  attribute :email
  attribute :status

  def id
    nil
  end
end
