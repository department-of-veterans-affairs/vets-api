# frozen_string_literal: true

class UpdateVeteranSubmission
  def initialize(job_id:, submission_type:, status:, upstream_system_name: nil, upstream_submission_id: nil)
    @job_id = job_id
    @submission_type = submission_type
    @status = status
    @upstream_system_name = upstream_system_name
    @upstream_submission_id = upstream_submission_id
  end

  def call
    veteran_submission = VeteranSubmission.find_by(va_gov_submission_id: @job_id, va_gov_submission_type: @submission_type)
    return unless veteran_submission

    veteran_submission.update!(
      status: @status,
      upstream_system_name: @upstream_system_name,
      upstream_submission_id: @upstream_submission_id
    )
  end
end
