# frozen_string_literal: true

class CreateVeteranSubmission
  def initialize(va_gov_submission_id, va_gov_submission_type)
    @va_gov_submission_id = va_gov_submission_id
    @va_gov_submission_type = va_gov_submission_type
  end

  def call
    VeteranSubmission.find_or_create_by!(
      va_gov_submission_id: @va_gov_submission_id,
      va_gov_submission_type: @va_gov_submission_type,
      status: :created
    )
  end
end
