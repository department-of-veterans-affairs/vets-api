# frozen_string_literal: true

require 'json_marshal/marshaller'

class SubmissionAttempt < ApplicationRecord
  self.abstract_class = true

  after_create :update_submission_status
  after_update :update_submission_status

  private

  def update_submission_status
    raise NotImplementedError, 'You must implement the update_submission_status method in your subclass'
  end
end
