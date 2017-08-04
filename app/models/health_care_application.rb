# frozen_string_literal: true
class HealthCareApplication < ActiveRecord::Base
  validates(:state, presence: true, inclusion: %w(success error failed pending))
  validates(:form_submission_id, :timestamp, presence: true, if: :success?)

  def success?
    state == 'success'
  end

  def set_result!(result)
    self.state = 'success'
    self.form_submission_id = result[:formSubmissionId]
    self.timestamp = result[:timestamp]

    save!
  end
end
