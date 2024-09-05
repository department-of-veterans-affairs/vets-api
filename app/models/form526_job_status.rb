# frozen_string_literal: true

class Form526JobStatus < ApplicationRecord
  belongs_to :form526_submission

  alias submission form526_submission

  FAILURE_STATUSES = {
    non_retryable_error: 'non_retryable_error',
    exhausted: 'exhausted'
  }.freeze
  STATUS = {
    try: 'try',
    success: 'success',
    retryable_error: 'retryable_error',
    pdf_not_found: 'pdf_not_found'
  }.merge(FAILURE_STATUSES).freeze

  store_accessor :bgjob_errors

  def success?
    status == STATUS[:success]
  end

  def unsuccessful?
    !success?
  end
end
