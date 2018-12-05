# frozen_string_literal: true

class PreferenceSerializer < ActiveModel::Serializer
  attribute :code
  attribute :title

  attribute :preference_choices do
    object.choices.select(%i[code description]).as_json(except: :id)
  end
end
