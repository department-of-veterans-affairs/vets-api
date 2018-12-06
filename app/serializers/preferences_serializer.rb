# frozen_string_literal: true

class PreferencesSerializer < ActiveModel::Serializer
  attribute :preferences

  def id
    nil
  end

  def preferences
    object.map do |o|
      {
        code: o.code,
        title: o.title,
        preference_choices: o.choices.select(%i[code description]).as_json(except: :id)
      }
    end
  end
end
