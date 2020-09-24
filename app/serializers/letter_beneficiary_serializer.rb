# frozen_string_literal: true

class LetterBeneficiarySerializer < ActiveModel::Serializer
  attribute :benefit_information
  attribute :military_service

  def id
    nil
  end
end
