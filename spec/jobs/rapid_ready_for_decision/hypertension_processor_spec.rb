# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'

RSpec.describe RapidReadyForDecision::HypertensionProcessor, type: :worker do
  before do
    Sidekiq::Worker.clear_all
  end

  let!(:user) { FactoryBot.create(:disabilities_compensation_user, icn: '2000163') }
  let(:auth_headers) do
    EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h)
  end
  let(:saved_claim) { FactoryBot.create(:va526ez) }
  let(:submission) do
    create(:form526_submission, :with_uploads, :hypertension_claim_for_increase,
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
    around do |example|
      VCR.use_cassette('evss/claims/claims_without_open_compensation_claims', &example)
    end

    before do
      # The bp reading needs to be 1 year or less old so actual API data will not test if this code is working.
      allow_any_instance_of(RapidReadyForDecision::LighthouseObservationData)
        .to receive(:transform).and_return(mocked_observation_data)
    end

    it 'finishes successfully' do
      Sidekiq::Testing.inline! do
        rrd_sidekiq_job = RapidReadyForDecision::Constants::DISABILITIES[:hypertension][:sidekiq_job]
        rrd_sidekiq_job.constantize.perform_async(submission.id)

        submission.reload
        expect(submission.form.dig('rrd_metadata', 'med_stats', 'bp_readings_count')).to eq 1
      end
    end

    it 'adds a special issue to the submission' do
      expect_any_instance_of(RapidReadyForDecision::RrdSpecialIssueManager).to receive(:add_special_issue)

      Sidekiq::Testing.inline! do
        RapidReadyForDecision::Form526BaseJob.perform_async(submission.id)
      end
    end

    context 'when the user uuid is not associated with an Account AND the edipi auth header is blank' do
      let(:submission_without_account_or_edpid) do
        auth_headers.delete('va_eauth_dodedipnid')

        create(:form526_submission, :hypertension_claim_for_increase,
               user_uuid: 'nonsense',
               auth_headers_json: auth_headers.to_json,
               saved_claim_id: saved_claim.id,
               submitted_claim_id: '600130094')
      end

      it 'raises an error' do
        Sidekiq::Testing.inline! do
          expect(submission_without_account_or_edpid.auth_headers['va_eauth_dodedipnid']).to be_blank

          expect do
            RapidReadyForDecision::Form526BaseJob.perform_async(submission_without_account_or_edpid.id)
          end.to raise_error RapidReadyForDecision::RrdProcessor::AccountNotFoundError
        end
      end
    end

    context 'when the user uuid is not associated with an Account AND the edipi auth header is present' do
      let(:submission_without_account) do
        create(:form526_submission, :hypertension_claim_for_increase,
               user_uuid: 'inconceivable',
               auth_headers_json: auth_headers.to_json,
               saved_claim_id: saved_claim.id,
               submitted_claim_id: '600130094')
      end

      it 'finishes successfully' do
        Sidekiq::Testing.inline! do
          expect do
            RapidReadyForDecision::Form526BaseJob.perform_async(submission_without_account.id)
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
            RapidReadyForDecision::Form526BaseJob.perform_async(submission.id)
          end.to raise_error RapidReadyForDecision::RrdProcessor::AccountNotFoundError
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
            RapidReadyForDecision::Form526BaseJob.perform_async(submission.id)
          end.to raise_error(ArgumentError, 'no ICN passed in for LH API request.')
        end
      end
    end
  end
end
