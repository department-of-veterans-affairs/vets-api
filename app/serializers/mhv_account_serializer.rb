# frozen_string_literal: true

class MHVAccountSerializer < ActiveModel::Serializer
  attribute :account_level
  attribute :account_state
  attribute :terms_and_conditions_accepted

  def terms_and_conditions_accepted
    object.terms_and_conditions_accepted?
  end
end
