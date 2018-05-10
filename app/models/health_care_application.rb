# frozen_string_literal: true

class HealthCareApplication < ActiveRecord::Base
  include TempFormValidation

  FORM_ID = '10-10EZ'

  attr_accessor(:user)

  validates(:state, presence: true, inclusion: %w[success error failed pending])
  validates(:form_submission_id_string, :timestamp, presence: true, if: :success?)

  def success?
    state == 'success'
  end

  def process!
    raise(Common::Exceptions::ValidationErrors, self) unless valid?

    if parsed_form[:email].present?
      save!
      HCA::SubmissionJob.perform_async(user&.uuid, form, id)
    else
      
    end
  end

  def set_result_on_success!(result)
    update_attributes!(
      state: 'success',
      # this is a string because it overflowed the postgres integer limit in one of the tests
      form_submission_id_string: result[:formSubmissionId].to_s,
      timestamp: result[:timestamp]
    )
  end

  def form_submission_id
    form_submission_id_string&.to_i
  end
end
