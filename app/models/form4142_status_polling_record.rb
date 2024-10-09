# frozen_string_literal: true

class Form4142StatusPollingRecord < ApplicationRecord
  validates :benefits_intake_uuid, presence: true
  validates :submission_id, presence: true

  enum :status, { pending: 0, errored: 1, success: 2 }, default: :pending


end
