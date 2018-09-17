# frozen_string_literal: true

class IntentToFileSerializer < ActiveModel::Serializer
  attribute :intent_to_file

  def id
    nil
  end
end
