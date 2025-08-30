# frozen_string_literal: true

require 'debts_api/v0/financial_status_report_service'

module DebtsApi
  class V0::DigitalDisputeJob
    def perform(submission_id, user_uuid)
      service = DigitalDisputeSubmissionService.new(current_user, submission_params[:files])
      service.call
    end
  end
end
