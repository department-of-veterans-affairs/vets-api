# frozen_string_literal: true

require 'upsert/active_record_upsert'

class Form526JobStatus < ApplicationRecord
  belongs_to :form526_submission

  alias_attribute :submission, :form526_submission

  STATUS = {
    try: 'try',
    success: 'success',
    retryable_error: 'retryable_error',
    non_retryable_error: 'non_retryable_error',
    exhausted: 'exhausted'
  }.freeze

  def success?
    status == STATUS[:success]
  end
end
