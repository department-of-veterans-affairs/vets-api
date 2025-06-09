# frozen_string_literal: true

require 'rails_helper'
require 'debts_api/v0/digital_dispute_submission_service'

RSpec.describe 'DebtsApi::V0::DigitalDisputes', type: :request do
  let(:user) { build(:user, :loa3) }
  let(:pdf_file_one) do
    fixture_file_upload('spec/fixtures/pdf_fill/686C-674/tester.pdf', 'application/pdf')
  end
  let(:mock_service) { instance_double(DebtsApi::V0::DigitalDisputeSubmissionService) }

  describe '#create' do
    context 'when authenticated' do
      before do
        sign_in_as(user)
        allow(StatsD).to receive(:increment)
        allow(DebtsApi::V0::DigitalDisputeSubmissionService).to receive(:new).and_return(mock_service)
      end

      describe 'successful submission' do
        before do
          allow(mock_service).to receive(:call).and_return({
                                                             success: true,
                                                             message: 'Digital dispute submission received successfully'
                                                           })
        end

        it 'returns 200 OK with success message' do
          post '/debts_api/v0/digital_disputes', params: { files: [pdf_file_one] }

          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)['message']).to eq('Digital dispute submission received successfully')
        end

        it 'tracks success metrics' do
          expect(StatsD).to receive(:increment).with('api.digital_dispute_submission.initiated')
          expect(StatsD).to receive(:increment).with('api.digital_dispute_submission.success')

          post '/debts_api/v0/digital_disputes', params: { files: [pdf_file_one] }
        end
      end

      describe 'failed validation' do
        before do
          allow(mock_service).to receive(:call).and_return({
                                                             success: false,
                                                             errors: { files: ['File 1 must be a PDF'] }
                                                           })
        end

        it 'returns 422 Unprocessable Entity with error details' do
          post '/debts_api/v0/digital_disputes', params: { files: [pdf_file_one] }

          expect(response).to have_http_status(:unprocessable_entity)
          expect(JSON.parse(response.body)).to eq(
            'errors' => { 'files' => ['File 1 must be a PDF'] }
          )
        end

        it 'tracks failure metrics' do
          expect(StatsD).to receive(:increment).with('api.digital_dispute_submission.initiated')
          expect(StatsD).to receive(:increment).with('api.digital_dispute_submission.failure')

          post '/debts_api/v0/digital_disputes', params: { files: [pdf_file_one] }
        end
      end

      describe 'server error handling' do
        before do
          allow(mock_service).to receive(:call).and_raise(StandardError.new('Unexpected error'))
        end

        it 'returns 500 Internal Server Error with generic message' do
          post '/debts_api/v0/digital_disputes', params: { files: [pdf_file_one] }

          expect(response).to have_http_status(:internal_server_error)
          expect(JSON.parse(response.body)).to eq(
            'errors' => { 'base' => ['An error occurred processing your submission'] }
          )
        end

        it 'tracks failure metrics' do
          expect(StatsD).to receive(:increment).with('api.digital_dispute_submission.initiated')
          expect(StatsD).to receive(:increment).with('api.digital_dispute_submission.failure')

          post '/debts_api/v0/digital_disputes', params: { files: [pdf_file_one] }
        end

        it 'logs the error' do
          expect(Rails.logger).to receive(:error).with('Digital dispute submission failed: Unexpected error')

          post '/debts_api/v0/digital_disputes', params: { files: [pdf_file_one] }
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

          post '/debts_api/v0/digital_disputes', params: { files: [pdf_file_one] }
        end
      end
    end
  end
end
