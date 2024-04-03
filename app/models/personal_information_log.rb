# frozen_string_literal: true

class PersonalInformationLog < ApplicationRecord
  scope :last_week, -> { where('created_at >= :date', date: 1.week.ago) }

  has_kms_key
  has_encrypted :data, key: :kms_key, **lockbox_options

  validates :error_class, presence: true

  def data=(value)
    super(JSON.generate(value))
  end

  def data
    JSON.parse(super)
  end

end
