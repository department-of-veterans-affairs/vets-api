# frozen_string_literal: true

require 'rails_helper'
require 'ostruct'
require 'lighthouse/benefits_intake/sidekiq/submission_status_job'
require 'dependents_benefits/benefits_intake/submission_handler'

RSpec.describe 'Dependents benefits intake status flow', type: :job do
  let(:job) { BenefitsIntake::SubmissionStatusJob.new }
  let(:service) { instance_double(BenefitsIntake::Service) }
  let(:claim) { create(:dependents_claim) }
  let(:submission) do
    create(:lighthouse_submission, form_id: DependentsBenefits::FORM_ID_V2, saved_claim_id: claim.id)
  end
  let!(:attempt) do
    create(:lighthouse_submission_attempt, :pending, submission:, benefits_intake_uuid: 'uuid-1')
  end
  let(:notification_email) do
    instance_double(DependentsBenefits::NotificationEmail, send_received_notification: true,
                                                           send_error_notification: true)
  end

  before do
    allow(Flipper).to receive(:enabled?).with(anything).and_call_original
    allow(Flipper).to receive(:enabled?).with(:benefits_intake_submission_status_job).and_return(true)
    allow(BenefitsIntake::Service).to receive(:new).and_return(service)
    allow(DependentsBenefits::NotificationEmail).to receive(:new).with(claim.id).and_return(notification_email)

    BenefitsIntake::SubmissionStatusJob.register_handler(
      DependentsBenefits::FORM_ID_V2,
      DependentsBenefits::BenefitsIntake::SubmissionHandler
    )
  end

  it 'checks pending attempts and updates to vbms with a received email' do
    response = OpenStruct.new(success?: true, body: {
                                'data' => [
                                  { 'id' => attempt.benefits_intake_uuid, 'attributes' => { 'status' => 'vbms' } }
                                ]
                              })

    expect(service).to receive(:bulk_status).with(uuids: [attempt.benefits_intake_uuid]).and_return(response)
    expect(notification_email).to receive(:send_received_notification).and_return(true)

    job.perform(DependentsBenefits::FORM_ID_V2)

    expect(attempt.reload.status).to eq('vbms')
  end

  it 'updates attempts to failure and sends an error email for error status' do
    response = OpenStruct.new(success?: true, body: {
                                'data' => [
                                  {
                                    'id' => attempt.benefits_intake_uuid,
                                    'attributes' => {
                                      'status' => 'error',
                                      'code' => 'ERR',
                                      'detail' => 'Upload failed'
                                    }
                                  }
                                ]
                              })

    expect(service).to receive(:bulk_status).with(uuids: [attempt.benefits_intake_uuid]).and_return(response)
    expect(notification_email).to receive(:send_error_notification).and_return(true)

    job.perform(DependentsBenefits::FORM_ID_V2)

    expect(attempt.reload.status).to eq('failure')
  end
end
