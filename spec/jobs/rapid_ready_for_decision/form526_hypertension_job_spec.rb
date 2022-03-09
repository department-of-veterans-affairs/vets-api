# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'

RSpec.describe RapidReadyForDecision::Form526HypertensionJob, type: :worker do
  subject { described_class }

  before do
    Sidekiq::Worker.clear_all
  end

  let!(:user) { FactoryBot.create(:disabilities_compensation_user, icn: '2000163') }
  let(:auth_headers) do
    EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h)
  end
  let(:saved_claim) { FactoryBot.create(:va526ez) }
  let(:submission) do
    create(:form526_submission, :with_uploads,
           user_uuid: user.uuid,
           auth_headers_json: auth_headers.to_json,
           saved_claim_id: saved_claim.id,
           submitted_claim_id: '600130094')
  end

  let(:mocked_observation_data) do
    [{ effectiveDateTime: "#{Time.zone.today.year}-06-21T02:42:52Z",
       practitioner: 'DR. THOMAS359 REYNOLDS206 PHD',
       organization: 'LYONS VA MEDICAL CENTER',
       systolic: { 'code' => '8480-6', 'display' => 'Systolic blood pressure', 'value' => 115.0,
                   'unit' => 'mm[Hg]' },
       diastolic: { 'code' => '8462-4', 'display' => 'Diastolic blood pressure', 'value' => 87.0,
                    'unit' => 'mm[Hg]' } }]
  end

  describe '#perform', :vcr do
    context 'success' do
      context 'the claim is NOT for hypertension' do
        let(:icn_for_user_without_bp_reading_within_one_year) { 17_000_151 }
        let!(:user) do
          FactoryBot.create(:disabilities_compensation_user, icn: icn_for_user_without_bp_reading_within_one_year)
        end
        let!(:submission_for_user_wo_bp) do
          create(:form526_submission, :with_uploads,
                 user_uuid: user.uuid,
                 auth_headers_json: auth_headers.to_json,
                 saved_claim_id: saved_claim.id,
                 submitted_claim_id: '600130094')
        end

        it 'returns from the class if the claim observations does NOT include bp readings from the past year' do
          Sidekiq::Testing.inline! do
            expect(RapidReadyForDecision::HypertensionMedicationRequestData).not_to receive(:new)
            subject.perform_async(submission_for_user_wo_bp.id)
          end
        end
      end

      context 'the claim IS for hypertension', :vcr do
        before do
          # The bp reading needs to be 1 year or less old so actual API data will not test if this code is working.
          allow_any_instance_of(RapidReadyForDecision::HypertensionObservationData)
            .to receive(:transform).and_return(mocked_observation_data)
        end

        it 'finishes successfully' do
          Sidekiq::Testing.inline! do
            expect do
              RapidReadyForDecision::Form526HypertensionJob.perform_async(submission.id)
            end.not_to raise_error
          end
        end

        it 'creates a job status record' do
          Sidekiq::Testing.inline! do
            expect do
              RapidReadyForDecision::Form526HypertensionJob.perform_async(submission.id)
            end.to change(Form526JobStatus, :count).by(1)
          end
        end

        it 'marks the new Form526JobStatus record as successful' do
          Sidekiq::Testing.inline! do
            RapidReadyForDecision::Form526HypertensionJob.perform_async(submission.id)
            expect(Form526JobStatus.last.status).to eq 'success'
          end
        end

        context 'failure' do
          before do
            allow_any_instance_of(
              RapidReadyForDecision::HypertensionPdfGenerator
            ).to receive(:generate).and_return(nil)
          end

          it 'raises a helpful error if the failure is after the api call and emails the engineers' do
            Sidekiq::Testing.inline! do
              expect do
                RapidReadyForDecision::Form526HypertensionJob.perform_async(submission.id)
              end.to raise_error(NoMethodError)
              expect(ActionMailer::Base.deliveries.last.subject).to eq 'Rapid Ready for Decision (RRD) Job Errored'
              expect(ActionMailer::Base.deliveries.last.body.raw_source)
                .to match 'A claim errored'
              expect(ActionMailer::Base.deliveries.last.body.raw_source.scan(/\n /).count).to be > 10
            end
          end

          it 'creates a job status record' do
            Sidekiq::Testing.inline! do
              expect do
                RapidReadyForDecision::Form526HypertensionJob.perform_async(submission.id)
              end.to raise_error(NoMethodError)
              expect(Form526JobStatus.last.status).to eq 'retryable_error'
            end
          end
        end
      end
    end

    context 'when the user uuid is not associated with an Account AND the edipi auth header is blank' do
      let(:submission_without_account_or_edpid) do
        create(:form526_submission,
               user_uuid: 'nonsense',
               auth_headers_json: auth_headers.delete('va_eauth_dodedipnid').to_json,
               saved_claim_id: saved_claim.id,
               submitted_claim_id: '600130094')
      end

      it 'raises an error' do
        Sidekiq::Testing.inline! do
          expect do
            RapidReadyForDecision::Form526HypertensionJob.perform_async(submission_without_account_or_edpid.id)
          end.to raise_error RapidReadyForDecision::Form526BaseJob::AccountNotFoundError
        end
      end
    end

    context 'when the user uuid is not associated with an Account AND the edipi auth header is present' do
      let(:submission_without_account) do
        create(:form526_submission, :with_uploads,
               user_uuid: 'inconceivable',
               auth_headers_json: auth_headers.to_json,
               saved_claim_id: saved_claim.id,
               submitted_claim_id: '600130094')
      end

      it 'finishes successfully' do
        Sidekiq::Testing.inline! do
          expect do
            subject.perform_async(submission_without_account.id)
          end.not_to raise_error
        end
      end
    end

    context 'when an account for the user is NOT found' do
      before do
        allow(Account).to receive(:where).and_return Account.none
        allow(Account).to receive(:find_by).and_return nil
      end

      it 'raises AccountNotFoundError exception' do
        Sidekiq::Testing.inline! do
          expect do
            RapidReadyForDecision::Form526HypertensionJob.perform_async(submission.id)
          end.to raise_error RapidReadyForDecision::Form526BaseJob::AccountNotFoundError
        end
      end
    end

    context 'when the ICN does NOT exist on the user Account' do
      before do
        allow_any_instance_of(Account).to receive(:icn).and_return('')
      end

      it 'raises an ArgumentError' do
        Sidekiq::Testing.inline! do
          expect do
            subject.perform_async(submission.id)
          end.to raise_error(ArgumentError, 'no ICN passed in for LH API request.')
        end
      end
    end
  end
end
