# frozen_string_literal: true

require 'rails_helper'
require 'debts_api/v0/digital_dispute_dmc_service'

RSpec.describe 'DebtsApi::V0::DigitalDisputes', type: :request do
  let(:user) { build(:user, :loa3) }
  let(:pdf_file_one) do
    fixture_file_upload('spec/fixtures/pdf_fill/686C-674/tester.pdf', 'application/pdf')
  end
  let(:metadata_json) do
    {
      'disputes' => [
        {
          'composite_debt_id' => '71166',
          'deduction_code' => '71',
          'original_ar' => 166.67,
          'current_ar' => 120.4,
          'benefit_type' => 'CH33 Books, Supplies/MISC EDU',
          'dispute_reason' => "I don't think I owe this debt to VA"
        }
      ]
    }.to_json
  end

  describe 'POST #create' do
    let(:mock_service) { instance_double(DebtsApi::V0::DigitalDisputeDmcService) }

    before do
      sign_in_as(user)
      allow(StatsD).to receive(:increment)
      allow(Flipper).to receive(:enabled?).with(:digital_dmc_dispute_service, anything).and_return(true)
      allow(DebtsApi::V0::DigitalDisputeDmcService).to receive(:new).and_return(mock_service)
    end

    describe 'authorization' do
      context 'when user ICN is blank' do
        let(:user) { build(:user, :loa3, icn: nil) }

        it 'returns forbidden' do
          post '/debts_api/v0/digital_disputes', params: { metadata: metadata_json, files: [pdf_file_one] }
          expect(response).to have_http_status(:forbidden)
        end
      end
    end

    describe 'successful submission' do
      before do
        allow(mock_service).to receive(:call!).and_return(
          success: true,
          message: 'Digital dispute submission received successfully'
        )
      end

      it 'returns 200 OK with success message' do
        post '/debts_api/v0/digital_disputes', params: { metadata: metadata_json, files: [pdf_file_one] }

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['message']).to eq('Submission received')
        expect(JSON.parse(response.body)['submission_id']).to be_present
      end

      it 'tracks success metrics' do
        expect(StatsD).to receive(:increment).with('api.digital_dispute_submission.initiated')
        expect(StatsD).to receive(:increment).with(
          'api.rack.request',
          {
            tags: %w[controller:debts_api/v0/digital_disputes action:create source_app:not_provided status:200]
          }
        )

        post '/debts_api/v0/digital_disputes', params: { metadata: metadata_json, files: [pdf_file_one] }
      end

      it 'enqueues the DigitalDisputeJob' do
        expect(DebtsApi::V0::DigitalDisputeJob).to receive(:perform_async).with(kind_of(Integer))
        post '/debts_api/v0/digital_disputes', params: { metadata: metadata_json, files: [pdf_file_one] }
      end
    end

    describe 'failed validation' do
      it 'returns 422 Unprocessable Entity with error details when no files are provided' do
        post '/debts_api/v0/digital_disputes', params: { metadata: metadata_json }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)).to eq(
          'errors' => { 'files' => ['Invalid file'] }
        )
      end

      it 'tracks failure metrics' do
        expect(StatsD).to receive(:increment).with('api.digital_dispute_submission.initiated')
        expect(StatsD).to receive(:increment).with('api.digital_dispute_submission.failure')
        expect(StatsD).to receive(:increment).with(
          'api.rack.request',
          {
            tags: %w[controller:debts_api/v0/digital_disputes action:create source_app:not_provided status:422]
          }
        )
        post '/debts_api/v0/digital_disputes', params: { metadata: metadata_json }
      end
    end

    describe 'email notifications' do
      before do
        allow(Flipper).to receive(:enabled?).with(:digital_dispute_email_notifications, anything).and_return(true)
      end

      it 'enqueues confirmation email when enabled and user has email' do
        expect(DebtsApi::V0::Form5655::SendConfirmationEmailJob).to receive(:perform_in).with(
          5.minutes,
          hash_including('submission_type' => 'digital_dispute', 'user_uuid' => user.uuid)
        )
        post '/debts_api/v0/digital_disputes', params: { metadata: metadata_json, files: [pdf_file_one] }
      end

      context 'when flipper disabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:digital_dispute_email_notifications, anything).and_return(false)
        end

        it 'does not enqueue confirmation email' do
          expect(DebtsApi::V0::Form5655::SendConfirmationEmailJob).not_to receive(:perform_in)
          post '/debts_api/v0/digital_disputes', params: { metadata: metadata_json, files: [pdf_file_one] }
        end
      end

      context 'when user has no email' do
        let(:user) { build(:user, :loa3, email: nil) }

        it 'does not enqueue confirmation email' do
          expect(DebtsApi::V0::Form5655::SendConfirmationEmailJob).not_to receive(:perform_in)
          post '/debts_api/v0/digital_disputes', params: { metadata: metadata_json, files: [pdf_file_one] }
        end
      end
    end
  end
end
