# frozen_string_literal: true

class EmailSerializer < ActiveModel::Serializer
  attribute :email_address, key: :email
  attribute :effective_date, key: :effective_at

  def id
    nil
  end

end
