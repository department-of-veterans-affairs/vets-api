# frozen_string_literal: true

class Form526JobStatus < ApplicationRecord
  belongs_to :form526_submission

  alias submission form526_submission

  STATUS = {
    try: 'try',
    success: 'success',
    retryable_error: 'retryable_error',
    non_retryable_error: 'non_retryable_error',
    exhausted: 'exhausted',
    pdf_not_found: 'pdf_not_found'
  }.freeze

  store_accessor :bgjob_errors

  def success?
    status == STATUS[:success]
  end

  def unsuccessful?
    !success?
  end
end
