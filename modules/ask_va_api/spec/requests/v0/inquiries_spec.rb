# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::V0::InquiriesController, type: :request do
  let(:inquiry_path) { '/ask_va_api/v0/inquiries' }
  let(:logger) { instance_double(LogService) }
  let(:span) { instance_double(Datadog::Tracing::Span) }
  let(:authorized_user) { build(:user, :accountable_with_sec_id, icn: '1008709396V637156') }
  let(:mock_inquiries) do
    JSON.parse(File.read('modules/ask_va_api/config/locales/get_inquiries_mock_data.json'))['data']
  end
  let(:valid_id) { mock_inquiries.first['id'] }
  let(:invalid_id) { 'invalid-id' }

  before do
    allow(LogService).to receive(:new).and_return(logger)
    allow(logger).to receive(:call).and_yield(span)
    allow(span).to receive(:set_tag)
    allow(Rails.logger).to receive(:error)
    allow_any_instance_of(Crm::CrmToken).to receive(:call).and_return('token')
  end

  shared_examples_for 'common error handling' do |status, action, error_message|
    it 'logs and renders error and sets datadog tags' do
      expect(response).to have_http_status(status)
      expect(JSON.parse(response.body)['error']).to eq(error_message)
      expect(logger).to have_received(:call).with(action)
      expect(span).to have_received(:set_tag).with('error', true)
      expect(span).to have_received(:set_tag).with('error.msg', error_message)
      expect(Rails.logger).to have_received(:error).with("Error during #{action}: #{error_message}")
    end
  end

  describe 'GET #index' do
    context 'when user is signed in' do
      before { sign_in(authorized_user) }

      context 'when everything is okay' do
        let(:json_response) do
          { 'id' => '1',
            'type' => 'inquiry',
            'attributes' =>
               { 'inquiry_number' => 'A-1',
                 'attachments' => [{ 'id' => '1', 'name' => 'testfile.txt' }],
                 'correspondences' => nil,
                 'has_attachments' => true,
                 'has_been_split' => true,
                 'level_of_authentication' => 'Personal',
                 'last_update' => '12/20/23',
                 'status' => 'In Progress',
                 'submitter_question' => 'What is my status?',
                 'school_facility_code' => '0123',
                 'topic' => 'Status of a pending claim',
                 'veteran_relationship' => 'self' } }
        end

        before { get inquiry_path, params: { mock: true } }

        it { expect(response).to have_http_status(:ok) }
        it { expect(JSON.parse(response.body)['data']).to include(json_response) }
      end

      context 'when an error occurs' do
        context 'when a service error' do
          let(:error_message) { 'service error' }

          before do
            allow_any_instance_of(Crm::Service)
              .to receive(:call)
              .and_raise(Crm::ErrorHandler::ServiceError.new(error_message))
            get inquiry_path
          end

          it_behaves_like 'common error handling', :unprocessable_entity, 'service_error',
                          'Crm::ErrorHandler::ServiceError: service error'
        end

        context 'when a standard error' do
          let(:error_message) { 'standard error' }

          before do
            allow_any_instance_of(Crm::Service)
              .to receive(:call)
              .and_raise(StandardError.new(error_message))
            get inquiry_path
          end

          it_behaves_like 'common error handling', :unprocessable_entity, 'service_error',
                          'StandardError: standard error'
        end
      end
    end

    context 'when user is not signed in' do
      before { get inquiry_path }

      it { expect(response).to have_http_status(:unauthorized) }
    end
  end

  describe 'GET #show' do
    let(:id) { valid_id }
    let(:expected_response) do
      { 'data' =>
        { 'id' => '1',
          'type' => 'inquiry',
          'attributes' =>
          { 'inquiry_number' => 'A-1',
            'attachments' => [{ 'id' => '1', 'name' => 'testfile.txt' }],
            'correspondences' => { 'data' => [{
              'id' => '1',
              'type' => 'correspondence',
              'attributes' => {
                'inquiry_id' => '1',
                'message_type' => '722310001: Response from VA',
                'modified_on' => '1/2/23',
                'status_reason' => 'Completed/Sent',
                'description' => 'Your claim is still In Progress',
                'enable_reply' => true,
                'attachments' => [
                  {
                    'id' => '12',
                    'name' => 'correspondence_1_attachment.pdf'
                  }
                ]
              }
            }] },
            'has_attachments' => true,
            'has_been_split' => true,
            'level_of_authentication' => 'Personal',
            'last_update' => '12/20/23',
            'status' => 'In Progress',
            'submitter_question' => 'What is my status?',
            'school_facility_code' => '0123',
            'topic' => 'Status of a pending claim',
            'veteran_relationship' => 'self' } } }
    end

    context 'when user is signed in' do
      before do
        sign_in(authorized_user)
        get "#{inquiry_path}/#{id}", params: { mock: true }
      end

      it { expect(response).to have_http_status(:ok) }
      it { expect(JSON.parse(response.body)).to eq(expected_response) }

      context 'when the id is invalid' do
        let(:id) { invalid_id }

        it { expect(response).to have_http_status(:bad_request) }

        it_behaves_like 'common error handling', :bad_request, 'invalid_inquiry_error',
                        'AskVAApi::V0::InquiriesController::InvalidInquiryError'
      end
    end

    context 'when an error occur' do
      before do
        allow(Crm::Service).to receive(:new).and_raise(ErrorHandler::ServiceError)
        sign_in(authorized_user)
        get "#{inquiry_path}/#{id}"
      end

      it { expect(JSON.parse(response.body)).to eq('error' => 'ErrorHandler::ServiceError') }
    end

    context 'when user is not signed in' do
      before do
        get "#{inquiry_path}/#{id}"
      end

      it { expect(response).to have_http_status(:unauthorized) }
    end
  end

  describe 'POST #unauth_create' do
    let(:params) { { first_name: 'Fake', last_name: 'Smith' } }
    let(:endpoint) { AskVAApi::Inquiries::Creator::ENDPOINT }

    before do
      allow_any_instance_of(Crm::Service).to receive(:call).with(endpoint:, method: :post,
                                                                 payload: { params: }).and_return('success')
      post inquiry_path, params:
    end

    it { expect(response).to have_http_status(:created) }
  end

  describe 'POST #upload_attachment' do
    let(:file_path) { 'modules/ask_va_api/config/locales/get_inquiries_mock_data.json' }
    let(:base64_encoded_file) { Base64.strict_encode64(File.read(file_path)) }
    let(:params) { { attachment: "data:image/png;base64,#{base64_encoded_file}", inquiry_id: '12345' } }

    context 'when the file is valid' do
      it 'returns an ok status' do
        post('/ask_va_api/v0/upload_attachment', params:)
        expect(response).to have_http_status(:ok)
        expect(json_response[:message]).to eq('Attachment has been received')
      end
    end

    context 'when no file is attached' do
      it 'returns a bad request status' do
        post '/ask_va_api/v0/upload_attachment', params: { inquiry_id: '12345' }
        expect(response).to have_http_status(:bad_request)
        expect(json_response[:message]).to eq('No file attached')
      end
    end

    context 'when the file size exceeds the limit' do
      let(:large_file) { double('File', size: 30.megabytes, content_type: 'application/pdf') }
      let(:large_base64_encoded_file) { Base64.strict_encode64('a' * large_file.size) }
      let(:large_file_params) do
        { attachment: "data:application/pdf;base64,#{large_base64_encoded_file}", inquiry_id: '12345' }
      end

      before do
        allow(File).to receive(:read).and_return('a' * large_file.size)
        post '/ask_va_api/v0/upload_attachment', params: large_file_params
      end

      it 'returns an unprocessable entity status' do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response[:message]).to eq('File size exceeds the allowed limit')
      end
    end

    # Helper method to parse JSON response
    def json_response
      JSON.parse(response.body, symbolize_names: true)
    end
  end

  describe 'POST #create' do
    let(:params) { { first_name: 'Fake', last_name: 'Smith' } }
    let(:endpoint) { AskVAApi::Inquiries::Creator::ENDPOINT }

    before do
      allow_any_instance_of(Crm::Service).to receive(:call).with(endpoint:, method: :post,
                                                                 payload: { params: }).and_return('success')
      sign_in(authorized_user)
      post '/ask_va_api/v0/inquiries/auth', params:
    end

    it { expect(response).to have_http_status(:created) }
  end

  describe 'GET #download_attachment' do
    let(:id) { '1' }

    before do
      sign_in(authorized_user)
      get '/ask_va_api/v0/download_attachment', params: { id:, mock: true }
    end

    it 'response with 200' do
      expect(response).to have_http_status(:ok)
    end

    context 'when attachment is not found' do
      let(:id) { 'not_valid' }

      it 'responds with 500' do
        expect(response).to have_http_status(:internal_server_error)
      end
    end
  end
end
