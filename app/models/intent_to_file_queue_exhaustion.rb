# frozen_string_literal: true

class IntentToFileQueueExhaustion < ApplicationRecord
  # class used to log and process ITF POST requests that have
  # failed to exhaustion. The exact details of what kind of
  # processing that will be done for retry attempts will be
  # specified in the future.
  validates :veteran_icn, presence: true

  STATUS = {
    unprocessed: 'unprocessed'
  }.freeze
end
