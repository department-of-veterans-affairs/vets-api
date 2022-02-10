# frozen_string_literal: true

class EligibilitySerializer < ActiveModel::Serializer
  attributes :veteran_is_eligbile, :chapter

  def id
    nil
  end
end
