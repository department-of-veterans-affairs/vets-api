# frozen_string_literal: true

require 'rails_helper'
require_relative 'submit_all_claim_spec/helper'

RSpec.describe(
  V0::DisabilityCompensationFormsController,
  '#submit_all_claim',
  type: :controller
) do
  include SubmitAllClaimSpec::Helper
  include ActiveSupport::Testing::TimeHelpers

  define_example('bdd', skip: true) do |definition|
    definition.payload_fixture = 'bdd'
    definition.user_icn = '1012666073V986297'

    definition.before do
      travel_to '2026-01-20T00:00:00Z' # to qualify for BDD

      allow_any_instance_of(EVSS::DisabilityCompensationForm::SubmitForm526).to(
        receive(:successfully_prepare_submission_for_evss?).and_return(true)
      )

      allow_any_instance_of(Form526Submission).to(
        receive_messages(
          send_submitted_email: nil,
          perform_ancillary_jobs_handler: nil
        )
      )
    end

    definition.assert do |submission|
      actual = submission.form526_job_statuses.pluck(:job_class, :status)
      expected = [%w[SubmitForm526AllClaim success]]
      expect(actual).to eq(expected)
    end
  end
end
