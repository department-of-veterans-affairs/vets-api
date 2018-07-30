# frozen_string_literal: true

class Form526OptInSerializer < ActiveModel::Serializer
  attribute :email

  def id
    nil
  end
end
