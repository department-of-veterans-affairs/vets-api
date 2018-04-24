# frozen_string_literal: true

class EmailSerializer < ActiveModel::Serializer
  attribute :email_address
  attribute :effective_date

  def id
    nil
  end
end
