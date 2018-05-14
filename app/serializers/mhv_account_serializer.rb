# frozen_string_literal: true

class MhvAccountSerializer < ActiveModel::Serializer
  attribute :account_state
  attribute :account_level

  def terms_and_conditions_accepted
    object.terms_and_conditions_accepted?
  end
end
