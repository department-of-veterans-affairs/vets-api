# frozen_string_literal: true

require 'rails_helper'
require 'debts_api/v0/digital_dispute_submission_service'
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

  describe '#create' do
    context 'when digital_dmc_dispute_service flipper disabled' do
      let(:mock_service) { instance_double(DebtsApi::V0::DigitalDisputeSubmissionService) }

      before do
        sign_in_as(user)
        allow(StatsD).to receive(:increment)
        allow(DebtsApi::V0::DigitalDisputeSubmissionService).to receive(:new).and_return(mock_service)
        allow(Flipper).to receive(:enabled?).with(:digital_dmc_dispute_service, anything).and_return(false)
      end

      describe 'successful submission' do
        before do
          allow(mock_service).to receive(:call).and_return({
                                                             success: true,
                                                             message: 'Digital dispute submission received successfully'
                                                           })
        end

        it 'returns 200 OK with success message' do
          post '/debts_api/v0/digital_disputes', params: { metadata: metadata_json, files: [pdf_file_one] }

          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)['message']).to eq('Digital dispute submission received successfully')
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
      end

      describe 'failed validation' do
        before do
          allow(mock_service).to receive(:call)
            .and_return(
              success: false,
              errors: { files: ['File 1 must be a PDF'] }
            )
        end

        it 'returns 422 Unprocessable Entity with error details' do
          post '/debts_api/v0/digital_disputes', params: { metadata: metadata_json, files: [pdf_file_one] }

          expect(response).to have_http_status(:unprocessable_entity)
          expect(JSON.parse(response.body)).to eq(
            'errors' => { 'files' => ['File 1 must be a PDF'] }
          )
        end

        it 'tracks failure metrics' do
          expect(StatsD).to receive(:increment).with('api.digital_dispute_submission.initiated')
          expect(StatsD).to receive(:increment).with(
            'api.rack.request',
            {
              tags: %w[controller:debts_api/v0/digital_disputes action:create source_app:not_provided status:422]
            }
          )

          post '/debts_api/v0/digital_disputes', params: { metadata: metadata_json, files: [pdf_file_one] }
        end
      end

      describe 'parameter handling' do
        it 'passes files to service using strong parameters' do
          expect(DebtsApi::V0::DigitalDisputeSubmissionService).to receive(:new) do |files|
            expect(files).to be_an(Array)
            expect(files.first).to be_a(ActionDispatch::Http::UploadedFile)
            expect(files.first.original_filename).to eq('tester.pdf')
            mock_service
          end
          allow(mock_service).to receive(:call).and_return({ success: true, message: 'Success' })

          post '/debts_api/v0/digital_disputes', params: { metadata: metadata_json, files: [pdf_file_one] }
        end
      end
    end

    context 'when digital_dmc_dispute_service flipper enabled' do
      let(:mock_service) { instance_double(DebtsApi::V0::DigitalDisputeDmcService) }

      before do
        sign_in_as(user)
        allow(StatsD).to receive(:increment)
        allow(Flipper).to receive(:enabled?).with(:digital_dmc_dispute_service, anything).and_return(true)
        allow(DebtsApi::V0::DigitalDisputeDmcService).to receive(:new).and_return(mock_service)
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
      end

      describe 'failed validation' do
        it 'returns 422 Unprocessable Entity with error details when no files are provided' do
          post '/debts_api/v0/digital_disputes', params: { metadata: metadata_json }

          expect(response).to have_http_status(:unprocessable_entity)
          expect(JSON.parse(response.body)).to eq(
            'errors' => { 'files' => ['at least one file is required'] }
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
    end
  end
end
