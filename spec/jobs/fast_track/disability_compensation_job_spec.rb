# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FastTrack::DisabilityCompensationJob, type: :worker do
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

  let(:user_full_name) { user.full_name_normalized }
  let(:mocked_observation_data) do
    [{ issued: "#{Time.zone.today.year}-03-23T01:15:52Z",
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
          expect(FastTrack::HypertensionMedicationRequestData).not_to receive(:new)
          expect(subject.new.perform(submission_for_user_wo_bp.id, user_full_name)).to be_nil
        end
      end

      context 'the claim IS for hypertension', :vcr do
        before do
          # The bp reading needs to be 1 year or less old so actual API data will not test if this code is working.
          allow_any_instance_of(FastTrack::HypertensionObservationData)
            .to receive(:transform).and_return(mocked_observation_data)
        end

        it 'emails the stakeholders' do
          expect { FastTrack::DisabilityCompensationJob.new.perform(submission.id, user_full_name) }
            .to change { ActionMailer::Base.deliveries.count }.by(1)
          expect(ActionMailer::Base.deliveries.last.subject).to eq 'Fast Track Hypertension Claim Submitted'
          expect(ActionMailer::Base.deliveries.last.body.raw_source)
            .to eq "A claim was just submitted on the #{Rails.env} environment with submission id: #{submission.id}"
        end

        it 'finishes successfully' do
          expect do
            FastTrack::DisabilityCompensationJob.new.perform(submission.id, user_full_name)
          end.not_to raise_error
        end

        context 'failure' do
          it 'raises a helpful error if the failure is after the api call' do
            allow_any_instance_of(
              SupportingEvidenceAttachment
            ).to receive(:save!).and_raise(StandardError)

            expect do
              FastTrack::DisabilityCompensationJob.new.perform(submission.id, user_full_name)
            end.to raise_error(StandardError)
          end
        end
      end
    end
  end
end
