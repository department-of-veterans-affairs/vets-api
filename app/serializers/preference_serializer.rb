# frozen_string_literal: true

class PreferenceSerializer < ActiveModel::Serializer
  attribute :code
  attribute :title
  attribute :preference_choices

  delegate :preference_choices, to: :object

  def id
    nil
  end
end
