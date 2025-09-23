# frozen_string_literal: true

class Form526JobStatus < ApplicationRecord
  belongs_to :form526_submission

  alias submission form526_submission

  FAILURE_STATUSES = {
    non_retryable_error: 'non_retryable_error',
    exhausted: 'exhausted'
  }.freeze
  SUCCESS_STATUSES = {
    success: 'success',
    pdf_found_later: 'pdf_found_later', # manually applied by dev when PDF is found after initial failure
    pdf_success_on_backup_path: 'pdf_success_on_backup_path', # manually applied by dev when PDF created via backup path
    pdf_manually_uploaded: 'pdf_manually_uploaded' # manually applied by dev when PDF is uploaded manually
  }.freeze
  STATUS = {
    try: 'try',
    success: 'success',
    retryable_error: 'retryable_error',
    pdf_not_found: 'pdf_not_found',
    pdf_found_later: 'pdf_found_later',
    pdf_success_on_backup_path: 'pdf_success_on_backup_path',
    pdf_manually_uploaded: 'pdf_manually_uploaded'
  }.merge(FAILURE_STATUSES).freeze

  store_accessor :bgjob_errors

  def success?
    SUCCESS_STATUSES.values.include?(status)
  end

  def unsuccessful?
    !success?
  end
end
