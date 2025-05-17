# frozen_string_literal: true

require './modules/decision_reviews/spec/dr_spec_helper'
require './modules/decision_reviews/spec/support/sidekiq_helper'
require './modules/decision_reviews/spec/support/vcr_helper'
require 'decision_reviews/v1/service'
require 'decision_reviews/v1/helpers'

RSpec.describe DecisionReviews::Form4142Submit, type: :job do
  include DecisionReviews::V1::Helpers

  subject { described_class }

  around do |example|
    Sidekiq::Testing.inline!(&example)
  end

  let(:notification_id) { SecureRandom.uuid }
  let(:vanotify_service) do
    service = instance_double(VaNotify::Service)

    response = instance_double(Notifications::Client::ResponseNotification, id: notification_id)
    allow(service).to receive(:send_email).and_return(response)

    service
  end

  let(:user_verification) { create(:idme_user_verification) }
  let(:user_account) { user_verification.user_account }
  let(:user_uuid) { create(:user, :loa3, idme_uuid: user_verification.idme_uuid, ssn: '212222112').uuid }
  let(:mpi_profile) { build(:mpi_profile, vet360_id: Faker::Number.number) }
  let(:find_profile_response) { create(:find_profile_response, profile: mpi_profile) }
  let(:mpi_service) do
    service = instance_double(MPI::Service, find_profile_by_identifier: nil)
    allow(service).to receive(:find_profile_by_identifier).with(identifier: user_account.icn, identifier_type: anything)
                                                          .and_return(find_profile_response)
    service
  end

  before do
    allow(VaNotify::Service).to receive(:new).and_return(vanotify_service)
    allow(MPI::Service).to receive(:new).and_return(mpi_service)
  end

  after do
    mpi_service { nil }
    vanotify_service { nil }
  end

  describe 'perform' do
    let(:submitted_appeal_uuid) { 'e076ea91-6b99-4912-bffc-a8318b9b403f' }
    let(:appeal_submission) do
      create(:appeal_submission_module, :with_one_upload_module, user_account:, submitted_appeal_uuid:,
                                                                 type_of_appeal: 'SC')
    end
    let(:user) { build(:user, :loa3) }
    let(:request_body) { VetsJsonSchema::EXAMPLES.fetch('SC-CREATE-REQUEST-BODY-FOR-VA-GOV') }

    context 'when form4142 data exists' do
      before do
        allow_any_instance_of(BenefitsIntake::Service).to receive(:valid_document?) do |_, document:|
          document
        end
      end

      it '#decrypt_form properly decrypts encrypted payloads' do
        form4142 = request_body['form4142']
        payload = get_and_rejigger_required_info(
          request_body:, form4142:, user:
        )
        enc_payload = payload_encrypted_string(payload)
        expect(subject.new.decrypt_form(enc_payload)).to eq(payload)
      end

      it 'generates a 4142 PDF and sends it to Lighthouse API' do
        VCR.use_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload_location') do
          VCR.use_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload') do
            expect do
              form4142 = request_body['form4142']
              payload = get_and_rejigger_required_info(
                request_body:, form4142:, user:
              )
              enc_payload = payload_encrypted_string(payload)
              subject.perform_async(appeal_submission.id, enc_payload, submitted_appeal_uuid)
              subject.drain
            end.to trigger_statsd_increment('worker.decision_review.form4142_submit.success', times: 1)
              .and trigger_statsd_increment('shared.sidekiq.default.DecisionReviews_Form4142Submit.enqueue',
                                            times: 1)
              .and trigger_statsd_increment('shared.sidekiq.default.DecisionReviews_Form4142Submit.dequeue',
                                            times: 1)
          end
        end
      end

      context 'when job fails permanently' do
        let(:msg) do
          {
            'jid' => 'job_id',
            'args' => [appeal_submission.id, 'encrypted_payload', submitted_appeal_uuid],
            'error_message' => 'An error occurred for sidekiq job'
          }
        end
        let(:tags) { ['service:supplemental-claims', 'function: secondary form submission to Lighthouse'] }
        let(:email_address) { 'testuser@test.com' }
        let(:form) do
          {
            data: {
              attributes: {
                veteran: {
                  email: email_address
                }
              }
            }
          }.to_json
        end

        before do
          SavedClaim::NoticeOfDisagreement.create(guid: submitted_appeal_uuid, form:)
        end

        it 'increments statsd correctly when email is sent' do
          expect { described_class.new.sidekiq_retries_exhausted_block.call(msg) }
            .to trigger_statsd_increment('worker.decision_review.form4142_submit.permanent_error')
            .and trigger_statsd_increment('worker.decision_review.form4142_submit.retries_exhausted.email_queued')
        end

        it 'increments statsd correctly for an error when sending an email' do
          expect(vanotify_service).to receive(:send_email).and_raise('Failed to send email')

          expect { described_class.new.sidekiq_retries_exhausted_block.call(msg) }
            .to trigger_statsd_increment('worker.decision_review.form4142_submit.permanent_error')
            .and trigger_statsd_increment('silent_failure', tags:)
            .and trigger_statsd_increment('worker.decision_review.form4142_submit.retries_exhausted.email_error',
                                          tags: ['appeal_type:SC'])
        end
      end
    end
  end
end
