# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'

RSpec.describe RapidReadyForDecision::Form526BaseJob, type: :worker do
  before { Flipper.disable(:rrd_call_vro_service) }

  let(:submission) { create(:form526_submission, :with_uploads, submitted_claim_id: '600130094') }

  let(:mocked_observation_data) do
    [{ effectiveDateTime: "#{Time.zone.today.year}-06-21T02:42:52Z",
       practitioner: 'DR. THOMAS359 REYNOLDS206 PHD',
       organization: 'LYONS VA MEDICAL CENTER',
       systolic: { 'code' => '8480-6', 'display' => 'Systolic BP', 'value' => 115.0, 'unit' => 'mm[Hg]' },
       diastolic: { 'code' => '8462-4', 'display' => 'Diastolic BP', 'value' => 87.0, 'unit' => 'mm[Hg]' } }]
  end

  describe '#perform' do
    around do |example|
      VCR.use_cassette('evss/claims/claims_without_open_compensation_claims', &example)
    end

    context 'the claim is NOT for hypertension' do
      let(:icn_for_user_without_bp_reading_within_one_year) { 17_000_151 }
      let!(:user) do
        FactoryBot.create(:disabilities_compensation_user, icn: icn_for_user_without_bp_reading_within_one_year)
      end
      let!(:submission_for_user_wo_bp) do
        create(:form526_submission, :with_uploads, user:, submitted_claim_id: '600130094')
      end

      it 'raises NoRrdProcessorForClaim' do
        Sidekiq::Testing.inline! do
          expect { described_class.perform_async(submission_for_user_wo_bp.id) }
            .to raise_error RapidReadyForDecision::Constants::NoRrdProcessorForClaim
        end
      end
    end

    context 'the claim IS for hypertension' do
      around do |example|
        VCR.use_cassette('rrd/hypertension', &example)
      end

      let(:submission) { create(:form526_submission, :hypertension_claim_for_increase) }

      before do
        # The bp reading needs to be 1 year or less old so actual API data will not test if this code is working.
        allow_any_instance_of(RapidReadyForDecision::LighthouseObservationData)
          .to receive(:transform).and_return(mocked_observation_data)
      end

      it 'creates a job status record' do
        Sidekiq::Testing.inline! do
          expect do
            described_class.perform_async(submission.id)
          end.to change(Form526JobStatus, :count).by(1)
        end
      end

      it 'marks the new Form526JobStatus record as successful' do
        Sidekiq::Testing.inline! do
          described_class.perform_async(submission.id)
          expect(Form526JobStatus.last.status).to eq 'success'
        end
      end

      context 'when rrd_{disability}_release_pdf Flipper flag does not exist' do
        before { expect(Flipper.exist?(:rrd_hypertension_release_pdf)).to eq false }

        it 'does release_pdf' do
          Sidekiq::Testing.inline! do
            described_class.perform_async(submission.id)

            submission.reload
            expect(submission.form['form526_uploads'].first['name']).to match(/Rapid_Decision_Evidence/)
            expect(submission.form.dig('form526', 'form526', 'disabilities').first['specialIssues']).to eq ['RRD']
          end
        end
      end

      context 'failure' do
        before do
          allow_any_instance_of(RapidReadyForDecision::FastTrackPdfGenerator).to receive(:generate).and_return(nil)
        end

        it 'raises a helpful error if the failure is after the api call and emails the engineers' do
          Sidekiq::Testing.inline! do
            expect do
              described_class.perform_async(submission.id)
            end.to raise_error(NoMethodError)
            expect(ActionMailer::Base.deliveries.last.subject).to eq 'Rapid Ready for Decision (RRD) Job Errored'
            expect(ActionMailer::Base.deliveries.last.body.raw_source)
              .to match 'The error was:'
            expect(ActionMailer::Base.deliveries.last.body.raw_source.scan(/\n /).count).to be > 10
          end
        end

        it 'creates a job status record' do
          Sidekiq::Testing.inline! do
            expect do
              described_class.perform_async(submission.id)
            end.to raise_error(NoMethodError)
            expect(Form526JobStatus.last.status).to eq 'retryable_error'
          end
        end
      end

      context 'when there are pending claims, which cause EP 400 errors' do
        it 'off-ramps to the non-RRD process' do
          VCR.use_cassette('evss/claims/claims') do
            Sidekiq::Testing.inline! do
              expect(Lighthouse::VeteransHealth::Client).not_to receive(:new)
              described_class.perform_async(submission.id)
              submission.reload
              expect(submission.form.dig('rrd_metadata', 'offramp_reason')).to eq 'pending_ep'
            end
          end
        end
      end
    end
  end
end
