# frozen_string_literal: true

class PersonalInformationLog < ActiveRecord::Base
  scope :last_week, -> { where('created_at >= :date', date: 1.week.ago) }
  validates(:data, :error_class, presence: true)
end
