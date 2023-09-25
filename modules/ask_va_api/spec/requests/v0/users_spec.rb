# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::V0::UsersController, type: :request do
  describe 'GET #show' do
    subject { get dashboard_path }

    let(:dashboard_path) { '/ask_va_api/v0/users/dashboard' }
    let(:authorized_user) do
      build(:user, :accountable_with_sec_id, email: 'vets.gov.user+228@gmail.com', sec_id: '0001740097')
    end

    shared_examples 'logs and renders error' do |status, action, error_message|
      it 'logs and renders error and sets datadog tags' do
        expect(response).to have_http_status(status)
        expect(JSON.parse(response.body)['error']).to eq(error_message)

        expect(datadog_logger).to have_received(:call).with(action)
        expect(span).to have_received(:set_tag).with('error', true)
        expect(span).to have_received(:set_tag).with('error.msg', error_message)
        expect(Rails.logger).to have_received(:error).with("Error during #{action}: #{error_message}")
      end
    end

    context 'when user is signed in' do
      before { sign_in(authorized_user) }

      context 'when user inquiries are successfully retrieved' do
        let(:json_response) do
          { 'data' => [
            {
              'id' => nil,
              'type' => 'inquiry',
              'attributes' => {
                'attachments' => nil,
                'inquiry_number' => 'A-1',
                'topic' => 'Topic',
                'question' => 'When is Sergeant Joe Smith birthday?',
                'processing_status' => 'Close',
                'last_update' => '08/07/23',
                'reply' => {
                  'data' => nil
                }
              }
            },
            {
              'id' => nil,
              'type' => 'inquiry',
              'attributes' => {
                'attachments' => nil,
                'inquiry_number' => 'A-2',
                'topic' => 'Topic',
                'question' => 'How long was Sergeant Joe Smith overseas for?',
                'processing_status' => 'In Progress',
                'last_update' => '08/07/23',
                'reply' => {
                  'data' => nil
                }
              }
            }
          ] }
        end

        before { subject }

        it { expect(response).to have_http_status(:ok) }
        it { expect(JSON.parse(response.body)).to eq(json_response) }
      end

      context 'when inquiry is not found' do
        let(:authorized_user) { build(:user, :accountable_with_sec_id, email: 'vets.gov.user+22@gmail.com') }

        before { subject }

        it { expect(response).to have_http_status(:ok) }
        it { expect(JSON.parse(response.body)).to eq({ 'data' => [] }) }
      end

      context 'when there is an error' do
        let(:datadog_logger) { instance_double(DatadogLogger) }
        let(:span) { instance_double(Datadog::Tracing::Span) }

        before do
          allow(DatadogLogger).to receive(:new).and_return(datadog_logger)
          allow(datadog_logger).to receive(:call).and_yield(span)
          allow(span).to receive(:set_tag)
          allow(Rails.logger).to receive(:error)
        end

        context 'when there is an error fetching inquiries' do
          let(:error_class) { ErrorHandler::ServiceError.new('Failed to fetch inquiries') }

          before do
            allow_any_instance_of(AskVAApi::Inquiries::Retriever).to receive(:fetch_by_sec_id).and_raise(error_class)
            subject
          end

          it_behaves_like 'logs and renders error', :unprocessable_entity, 'service_error', 'Failed to fetch inquiries'
        end

        context 'when ArgumentError is raised' do
          let(:error_message) { 'Invalid Argument' }

          before do
            allow_any_instance_of(AskVAApi::Inquiries::Retriever)
              .to receive(:fetch_by_sec_id)
              .and_raise(ArgumentError.new(error_message))
            subject
          end

          it_behaves_like 'logs and renders error', :bad_request, 'argument_error', 'Invalid Argument'
        end
      end
    end

    context 'when the user is not signed in' do
      before { subject }

      it { expect(response).to have_http_status(:unauthorized) }
    end
  end
end
