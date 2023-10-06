# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::V0::InquiriesController, type: :request do
  let(:inquiry_path) { '/ask_va_api/v0/inquiries' }
  let(:datadog_logger) { instance_double(DatadogLogger) }
  let(:span) { instance_double(Datadog::Tracing::Span) }
  let(:authorized_user) { build(:user, :accountable_with_sec_id, sec_id: '0001740097') }
  let(:mock_inquiries) do
    JSON.parse(File.read('modules/ask_va_api/config/locales/get_inquiries_mock_data.json'))['data']
  end
  let(:valid_inquiry_number) { mock_inquiries.first['inquiryNumber'] }
  let(:invalid_inquiry_number) { 'invalid-number' }

  before do
    allow(DatadogLogger).to receive(:new).and_return(datadog_logger)
    allow(datadog_logger).to receive(:call).and_yield(span)
    allow(span).to receive(:set_tag)
    allow(Rails.logger).to receive(:error)
  end

  shared_examples_for 'common error handling' do |status, action, error_message|
    it 'logs and renders error and sets datadog tags' do
      expect(response).to have_http_status(status)
      expect(JSON.parse(response.body)['error']).to eq(error_message)
      expect(datadog_logger).to have_received(:call).with(action)
      expect(span).to have_received(:set_tag).with('error', true)
      expect(span).to have_received(:set_tag).with('error.msg', error_message)
      expect(Rails.logger).to have_received(:error).with("Error during #{action}: #{error_message}")
    end
  end

  describe 'GET #index' do
    subject { get inquiry_path }

    context 'when user is signed in' do
      before { sign_in(authorized_user) }

      context 'when everything is okay' do
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

      context 'when an error occurs' do
        context 'when a service error' do
          let(:error_message) { 'service error' }

          before do
            allow_any_instance_of(Dynamics::Service)
              .to receive(:call)
              .and_raise(Dynamics::ErrorHandler::BadRequestError.new(error_message))
            subject
          end

          it_behaves_like 'common error handling', :unprocessable_entity, 'service_error',
                          'Bad Request Error: service error'
        end

        context 'when a standard error' do
          let(:error_message) { 'standard error' }

          before do
            allow_any_instance_of(Dynamics::Service)
              .to receive(:call)
              .and_raise(StandardError.new(error_message))
            subject
          end

          it_behaves_like 'common error handling', :unprocessable_entity, 'service_error',
                          ': standard error'
        end
      end
    end

    context 'when user is not signed in' do
      before { subject }

      it { expect(response).to have_http_status(:unauthorized) }
    end
  end

  describe 'GET #show' do
    subject { get "#{inquiry_path}/#{inquiry_number}" }

    let(:inquiry_number) { valid_inquiry_number }
    let(:expected_response) do
      { 'data' =>
        { 'id' => nil,
          'type' => 'inquiry',
          'attributes' =>
          { 'attachments' => [{ 'activity' => 'activity_1', 'date_sent' => '08/7/23' }],
            'inquiry_number' => 'A-1',
            'topic' => 'Topic',
            'question' => 'When is Sergeant Joe Smith birthday?',
            'processing_status' => 'Close',
            'last_update' => '08/07/23',
            'reply' =>
            { 'data' =>
              { 'id' => 'R-1',
                'type' => 'correspondence',
                'attributes' => { 'inquiry_number' => 'A-1',
                                  'correspondence' => 'Sergeant Joe Smith birthday is July 4th, 1980' } } } } } }
    end

    context 'when user is signed in' do
      before do
        sign_in(authorized_user)
        subject
      end

      it { expect(response).to have_http_status(:ok) }
      it { expect(JSON.parse(response.body)).to eq(expected_response) }

      context 'when the inquiry number is invalid' do
        let(:inquiry_number) { invalid_inquiry_number }

        it { expect(response).to have_http_status(:bad_request) }

        it_behaves_like 'common error handling', :bad_request, 'invalid_inquiry_error',
                        'AskVAApi::V0::InquiriesController::InvalidInquiryError'
      end
    end

    context 'when an error occur' do
      before do
        allow(Dynamics::Service).to receive(:new).and_raise(ErrorHandler::ServiceError)
        sign_in(authorized_user)
        subject
      end

      it { expect(JSON.parse(response.body)).to eq('error' => 'ErrorHandler::ServiceError') }
    end

    context 'when user is not signed in' do
      before { subject }

      it { expect(response).to have_http_status(:unauthorized) }
    end
  end
end
