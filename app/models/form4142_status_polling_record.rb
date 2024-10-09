# frozen_string_literal: true

class Form4142StatusPollingRecord < ApplicationRecord

  enum :status, {pending: 0, errored: 1, success: 2}, default: :pending

  scope :needs_polled -> {where(status: :pending)}


end
