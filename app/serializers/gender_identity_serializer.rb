# frozen_string_literal: true

class GenderIdentitySerializer < ActiveModel::Serializer
  attributes :gender_identity

  def id
    nil
  end
end
