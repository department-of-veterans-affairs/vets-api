# frozen_string_literal: true

require 'rails_helper'
require AskVAApi::Engine.root.join('spec', 'support', 'shared_contexts.rb')

RSpec.describe 'AskVAApi::V0::Inquiries', type: :request do
  # allow to have access to inquiry_param
  include_context 'shared data'

  let(:inquiry_path) { '/ask_va_api/v0/inquiries' }
  let(:logger) { instance_double(LogService) }
  let(:span) { instance_double(Datadog::Tracing::Span) }
  let(:icn) { I18n.t('ask_va_api.test_users.test_user_229_icn') }
  let(:authorized_user) { build(:user, :accountable_with_sec_id, icn:) }
  let(:mock_inquiries) do
    JSON.parse(File.read('modules/ask_va_api/config/locales/get_inquiries_mock_data.json'))['Data']
  end
  let(:valid_id) { mock_inquiries.first['InquiryNumber'] }
  let(:invalid_id) { 'A-20240423-30709' }
  let(:static_data_mock) { File.read('modules/ask_va_api/config/locales/static_data.json') }
  let(:cache_data) { JSON.parse(static_data_mock, symbolize_names: true) }
  let(:patsr_facilities) do
    data = File.read('modules/ask_va_api/config/locales/get_facilities_mock_data.json')
    JSON.parse(data, symbolize_names: true)
  end

  before do
    allow(LogService).to receive(:new).and_return(logger)
    allow(logger).to receive(:call).and_yield(span)
    allow(span).to receive(:set_tag)
    allow(span).to receive(:set_error)
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
          { 'id' => '4',
            'type' => 'inquiry',
            'attributes' =>
             { 'inquiry_number' => 'A-4',
               'allow_attachments' => nil,
               'allow_replies' => nil,
               'has_attachments' => true,
               'attachments' => [{ 'Id' => '4', 'Name' => 'testfile.txt' }],
               'category_name' => 'Benefits issues outside the U.S.',
               'created_on' => '8/5/2024 4:51:52 PM',
               'correspondences' => nil,
               'has_been_split' => true,
               'inquiry_topic' => 'All other Questions',
               'level_of_authentication' => 'Personal',
               'last_update' => '8/5/2024 4:51:52 PM',
               'queue_id' => '987654',
               'queue_name' => 'Compensation',
               'status' => 'In Progress',
               'submitter_question' => 'What is compensation?',
               'school_facility_code' => '0123',
               'veteran_relationship' => 'self' } }
        end

        before { get inquiry_path, params: { user_mock_data: true, page: 1, per_page: 10 } }

        it { expect(response).to have_http_status(:ok) }
        it { expect(JSON.parse(response.body)['data']).to include(json_response) }
      end

      context 'when an error occurs' do
        context 'when Multiple Contacts found by ICN' do
          let(:service) { instance_double(Crm::Service) }
          let(:body) do
            '{"Data":null,"Message":"Data Validation: Multiple Contacts found by ICN"' \
              ',"ExceptionOccurred":true,"ExceptionMessage"' \
              ':"Data Validation: No Contact found by ICN","MessageId":"19d9799c-159f-4901-8672-6bdfc1d4cc0f"}'
          end
          let(:failure) { Faraday::Response.new(response_body: body, status: 400) }

          before do
            allow(Crm::Service).to receive(:new).and_return(service)
            allow_any_instance_of(Crm::CrmToken).to receive(:call).and_return('Token')
            allow(service).to receive(:call).and_return(failure)
            get inquiry_path
          end

          it_behaves_like 'common error handling', :unprocessable_entity, 'service_error',
                          'AskVAApi::Inquiries::InquiriesRetrieverError:' \
                          ' {"Data":null,"Message":"Data Validation: Multiple Contacts found by ICN"' \
                          ',"ExceptionOccurred":true,"ExceptionMessage":"Data Validation: No Contact found by ICN",' \
                          '"MessageId":"19d9799c-159f-4901-8672-6bdfc1d4cc0f"}'
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
    let(:expected_response) do
      { 'data' =>
        { 'id' => '1',
          'type' => 'inquiry',
          'attributes' =>
          { 'inquiry_number' => 'A-1',
            'allow_attachments' => nil,
            'allow_replies' => nil,
            'has_attachments' => true,
            'attachments' => [{ 'Id' => '1', 'Name' => 'testfile.txt' }],
            'category_name' => 'Debt for benefit overpayments and health care copay bills',
            'created_on' => '8/5/2024 4:51:52 PM',
            'correspondences' =>
            { 'data' =>
              [{ 'id' => '1',
                 'type' => 'correspondence',
                 'attributes' =>
                 { 'message_type' => '722310001: Response from VA',
                   'created_on' => '1/2/23 4:45:45 PM',
                   'modified_on' => '1/2/23 5:45:45 PM',
                   'status_reason' => 'Completed/Sent',
                   'description' => 'Your claim is still In Progress',
                   'enable_reply' => true,
                   'attachments' => [{ 'Id' => '12', 'Name' => 'correspondence_1_attachment.pdf' }] } }] },
            'has_been_split' => true,
            'inquiry_topic' => 'Status of a pending claim',
            'level_of_authentication' => 'Personal',
            'last_update' => '8/5/2024 4:51:52 PM',
            'queue_id' => '987654',
            'queue_name' => 'Debt Management Center',
            'status' => 'Replied',
            'submitter_question' => 'What is my status?',
            'school_facility_code' => '0123',
            'veteran_relationship' => 'self' } } }
    end

    before do
      allow_any_instance_of(AskVAApi::RedisClient).to receive(:fetch)
        .with('categories_topics_subtopics')
        .and_return(cache_data)
    end

    context 'when user is signed in' do
      context 'when mock is given' do
        before do
          sign_in(authorized_user)
          get "#{inquiry_path}/#{valid_id}", params: { user_mock_data: true }
        end

        it { expect(response).to have_http_status(:ok) }
        it { expect(JSON.parse(response.body)).to eq(expected_response) }
      end

      context 'when mock is not given' do
        let(:crm_response) do
          { Data: [{
            InquiryHasBeenSplit: true,
            CategoryId: '5c524deb-d864-eb11-bb24-000d3a579c45',
            CreatedOn: '8/5/2024 4:51:52 PM',
            Id: 'a6c3af1b-ec8c-ee11-8178-001dd804e106',
            InquiryLevelOfAuthentication: 'Personal',
            InquiryNumber: 'A-123456',
            InquiryStatus: 'In Progress',
            InquiryTopic: 'Cemetery Debt',
            LastUpdate: '8/5/2024 4:51:52 PM',
            QueueId: '9876t54',
            QueueName: 'Debt Management Center',
            SchoolFacilityCode: '0123',
            SubmitterQuestion: 'My question is... ',
            VeteranRelationship: 'self',
            AttachmentNames: [
              {
                Id: '012345',
                Name: 'File A.pdf'
              }
            ]
          }] }
        end
        let(:expected_response) do
          { 'data' =>
            { 'id' => 'a6c3af1b-ec8c-ee11-8178-001dd804e106',
              'type' => 'inquiry',
              'attributes' =>
              { 'inquiry_number' => 'A-123456',
                'allow_attachments' => nil,
                'allow_replies' => nil,
                'has_attachments' => nil,
                'attachments' => [{ 'Id' => '012345', 'Name' => 'File A.pdf' }],
                'category_name' => 'Debt for benefit overpayments and health care copay bills',
                'created_on' => '8/5/2024 4:51:52 PM',
                'correspondences' =>
                { 'data' =>
                  [{ 'id' => 'a6c3af1b-ec8c-ee11-8178-001dd804e106',
                     'type' => 'correspondence',
                     'attributes' =>
                     { 'message_type' => nil,
                       'created_on' => '8/5/2024 4:51:52 PM',
                       'modified_on' => nil,
                       'status_reason' => nil,
                       'description' => nil,
                       'enable_reply' => nil,
                       'attachments' => [{ 'Id' => '012345', 'Name' => 'File A.pdf' }] } }] },
                'has_been_split' => true,
                'inquiry_topic' => 'Cemetery Debt',
                'level_of_authentication' => 'Personal',
                'last_update' => '8/5/2024 4:51:52 PM',
                'queue_id' => '9876t54',
                'queue_name' => 'Debt Management Center',
                'status' => 'In Progress',
                'submitter_question' => 'My question is... ',
                'school_facility_code' => '0123',
                'veteran_relationship' => 'self' } } }
        end
        let(:service) { instance_double(Crm::Service) }

        before do
          allow(Crm::Service).to receive(:new).and_return(service)
          allow_any_instance_of(Crm::CrmToken).to receive(:call).and_return('Token')
          allow(service).to receive(:call).and_return(crm_response)
          sign_in(authorized_user)
          get "#{inquiry_path}/#{valid_id}"
        end

        it { expect(response).to have_http_status(:ok) }
        it { expect(JSON.parse(response.body)).to eq(expected_response) }
      end

      context 'when the id is invalid' do
        let(:body) do
          '{"Data":null,"Message":"Data Validation: No Inquiries found by ID A-20240423-30709"' \
            ',"ExceptionOccurred":true,"ExceptionMessage":"Data Validation: No Inquiries found by ' \
            'ID A-20240423-30709","MessageId":"ca5b990a-63fe-407d-a364-46caffce12c1"}'
        end
        let(:failure) { Faraday::Response.new(response_body: body, status: 400) }
        let(:service) { instance_double(Crm::Service) }

        before do
          allow(Crm::Service).to receive(:new).and_return(service)
          allow_any_instance_of(Crm::CrmToken).to receive(:call).and_return('Token')
          allow(service).to receive(:call).and_return(failure)
          sign_in(authorized_user)
          get "#{inquiry_path}/#{invalid_id}"
        end

        it { expect(response).to have_http_status(:unprocessable_entity) }

        it_behaves_like 'common error handling', :unprocessable_entity, 'service_error',
                        'AskVAApi::Inquiries::InquiriesRetrieverError: ' \
                        '{"Data":null,"Message":"Data Validation: No Inquiries found by ID A-20240423-30709"' \
                        ',"ExceptionOccurred":true,"ExceptionMessage":"Data Validation: No Inquiries found by ' \
                        'ID A-20240423-30709","MessageId":"ca5b990a-63fe-407d-a364-46caffce12c1"}'
      end
    end
  end

  describe 'GET #download_attachment' do
    let(:id) { '1' }

    before do
      sign_in(authorized_user)
    end

    context 'when successful' do
      before do
        get '/ask_va_api/v0/download_attachment', params: { id:, mock: true }
      end

      it 'response with 200' do
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when Crm raise an error' do
      let(:body) do
        '{"Data":null,"Message":"Data Validation: Invalid GUID, Parsing Failed",' \
          '"ExceptionOccurred":true,"ExceptionMessage":"Data Validation: Invalid GUID,' \
          ' Parsing Failed","MessageId":"c14c61c4-a3a8-4200-8c86-bdc09c261308"}'
      end
      let(:failure) { Faraday::Response.new(response_body: body, status: 400) }

      before do
        allow_any_instance_of(Crm::CrmToken).to receive(:call).and_return('token')
        allow_any_instance_of(Crm::Service).to receive(:call)
          .with(endpoint: 'attachment', payload: { id: '1' }).and_return(failure)
        get '/ask_va_api/v0/download_attachment', params: { id:, mock: nil }
      end

      it 'raise the error' do
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'GET #profile' do
    context 'when a user is signed in' do
      before do
        sign_in(authorized_user)
        get '/ask_va_api/v0/profile', params: { user_mock_data: true }
      end

      it 'response with 200' do
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when the service call fails' do
      subject(:retriever) { described_class.new(icn: '123') }

      let(:body) do
        '{"Data":null,"Message":"Data Validation: No Contact found"' \
          ',"ExceptionOccurred":true,"ExceptionMessage":"Data Validation: No Contact found ' \
          '","MessageId":"ca5b990a-63fe-407d-a364-46caffce12c1"}'
      end
      let(:service) { instance_double(Crm::Service) }
      let(:failure) { Faraday::Response.new(response_body: body, status: 400) }

      before do
        allow(Crm::Service).to receive(:new).and_return(service)
        allow(service).to receive(:call)
        allow_any_instance_of(Crm::CrmToken).to receive(:call).and_return('Token')
        allow(service).to receive(:call).and_return(failure)
        sign_in(authorized_user)
        get '/ask_va_api/v0/profile'
      end

      it 'raise InvalidProfileError' do
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it_behaves_like 'common error handling', :unprocessable_entity, 'service_error',
                      'AskVAApi::Profile::InvalidProfileError: ' \
                      '{"Data":null,"Message":"Data Validation: No Contact found"' \
                      ',"ExceptionOccurred":true,"ExceptionMessage":"Data Validation: No Contact found ' \
                      '","MessageId":"ca5b990a-63fe-407d-a364-46caffce12c1"}'
    end
  end

  describe 'GET #status' do
    context 'When succesful' do
      before do
        allow_any_instance_of(Crm::CrmToken).to receive(:call).and_return('Token')
        allow_any_instance_of(Crm::Service)
          .to receive(:call).and_return({
                                          Data: {
                                            Status: 'Reopened',
                                            InquiryLevelOfAuthentication: 'Personal'
                                          },
                                          Message: nil,
                                          ExceptionOccurred: false,
                                          ExceptionMessage: nil,
                                          MessageId: '26f5be95-87c6-47f0-9722-1abb5f1a59b5'
                                        })
        get "/ask_va_api/v0/inquiries/#{valid_id}/status"
      end

      it 'returns the status for the given inquiry id' do
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['data']).to eq({ 'id' => nil,
                                                          'type' => 'inquiry_status',
                                                          'attributes' => { 'status' => 'Reopened' } })
      end
    end

    context 'When not successful' do
      let(:endpoint) { AskVAApi::Inquiries::Status::Retriever::ENDPOINT }
      let(:body) do
        '{"Data":null,"Message":"Data Validation: No Inquiries found",' \
          '"ExceptionOccurred":true,' \
          '"ExceptionMessage":"Data Validation: No Inquiries found",' \
          '"MessageId":"28cda301-5977-4052-a391-9ab36d514919"}'
      end
      let(:failure) { Faraday::Response.new(response_body: body, status: 400) }
      let(:payload) { { InquiryNumber: 'A-1' } }

      before do
        allow_any_instance_of(Crm::CrmToken).to receive(:call).and_return('Token')
        allow_any_instance_of(Crm::Service).to receive(:call)
          .with(endpoint:, payload:).and_return(failure)
        get "/ask_va_api/v0/inquiries/#{valid_id}/status"
      end

      it 'raise StatusRetrieverError' do
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it_behaves_like 'common error handling', :unprocessable_entity, 'service_error',
                      'AskVAApi::Inquiries::Status::StatusRetrieverError: ' \
                      '{"Data":null,"Message":"Data Validation: No Inquiries found",' \
                      '"ExceptionOccurred":true,' \
                      '"ExceptionMessage":"Data Validation: No Inquiries found",' \
                      '"MessageId":"28cda301-5977-4052-a391-9ab36d514919"}'
    end
  end

  describe 'when creating an inquiry' do
    let(:file_path) { 'modules/ask_va_api/config/locales/get_inquiries_mock_data.json' }
    let(:base64_encoded_file) { Base64.strict_encode64(File.read(file_path)) }
    let(:file) { "data:image/png;base64,#{base64_encoded_file}" }
    let(:endpoint) { AskVAApi::Inquiries::Creator::ENDPOINT }
    let(:cache_data_service) { instance_double(Crm::CacheData) }
    let(:cached_data) do
      data = File.read('modules/ask_va_api/config/locales/get_optionset_mock_data.json')
      JSON.parse(data, symbolize_names: true)
    end
    let(:safe_fields) do
      %i[category_id
         contact_preference
         family_members_location_of_residence
         is_question_about_veteran_or_someone_else
         more_about_your_relationship_to_veteran
         relationship_to_veteran
         select_category
         select_topic
         subtopic_id
         topic_id
         veterans_postal_code
         who_is_your_question_about]
    end

    before do
      allow(Crm::CacheData).to receive(:new).and_return(cache_data_service)
      allow(cache_data_service).to receive(:call).with(
        endpoint: 'optionset',
        cache_key: 'optionset'
      ).and_return(cached_data)
      allow(cache_data_service).to receive(:fetch_and_cache_data).and_return(patsr_facilities)
    end

    context 'POST #create' do
      context 'when successful' do
        before do
          allow_any_instance_of(Crm::Service).to receive(:call)
            .and_return({
                          Data: {
                            Id: '530d56a8-affd-ee11-a1fe-001dd8094ff1'
                          },
                          Message: '',
                          ExceptionOccurred: false,
                          ExceptionMessage: '',
                          MessageId: 'b8ebd8e7-3bbf-49c5-aff0-99503e50ee27'
                        })
          sign_in(authorized_user)
          # inquiry_params is in include_context 'shared data'
          post '/ask_va_api/v0/inquiries/auth', params: inquiry_params
        end

        it { expect(response).to have_http_status(:created) }
      end

      context 'when crm api fail' do
        context 'when the API call fails' do
          let(:body) do
            '{"Data":null,"Message":"Data Validation: missing InquiryCategory"' \
              ',"ExceptionOccurred":true,"ExceptionMessage":"Data Validation: missing' \
              'InquiryCategory","MessageId":"cb0dd954-ef25-4e56-b0d9-41925e5a190c"}'
          end
          let(:failure) { Faraday::Response.new(response_body: body, status: 400) }

          before do
            allow_any_instance_of(Crm::Service).to receive(:call)
              .and_return(failure)
            sign_in(authorized_user)
            post '/ask_va_api/v0/inquiries/auth', params: inquiry_params
          end

          it 'raise InquiriesCreatorError and set span safe_fields' do
            expect(response).to have_http_status(:unprocessable_entity)
            safe_fields.each do |field|
              expect(span).to have_received(:set_tag).with(
                "safe_field.#{field}",
                inquiry_params[:inquiry][field]
              )
            end
          end

          it_behaves_like 'common error handling', :unprocessable_entity, 'service_error',
                          'InquiriesCreatorError: {"Data":null,"Message":' \
                          '"Data Validation: missing InquiryCategory"' \
                          ',"ExceptionOccurred":true,"ExceptionMessage":"Data Validation: missing' \
                          'InquiryCategory","MessageId":"cb0dd954-ef25-4e56-b0d9-41925e5a190c"}'
        end
      end
    end

    context 'POST #unauth_create' do
      let(:icn) { nil }

      context 'when successful' do
        before do
          allow_any_instance_of(Crm::Service).to receive(:call)
            .and_return({
                          Data: {
                            Id: '530d56a8-affd-ee11-a1fe-001dd8094ff1'
                          },
                          Message: '',
                          ExceptionOccurred: false,
                          ExceptionMessage: '',
                          MessageId: 'b8ebd8e7-3bbf-49c5-aff0-99503e50ee27'
                        })
          post inquiry_path, params: inquiry_params
        end

        it { expect(response).to have_http_status(:created) }
      end

      context 'when crm api fail' do
        context 'when the API call fails' do
          let(:body) do
            '{"Data":null,"Message":"Data Validation: missing InquiryCategory"' \
              ',"ExceptionOccurred":true,"ExceptionMessage":"Data Validation: missing' \
              'InquiryCategory","MessageId":"cb0dd954-ef25-4e56-b0d9-41925e5a190c"}'
          end
          let(:failure) { Faraday::Response.new(response_body: body, status: 400) }

          before do
            allow_any_instance_of(Crm::Service).to receive(:call)
              .and_return(failure)
            post '/ask_va_api/v0/inquiries', params: inquiry_params
          end

          it 'raise InquiriesCreatorError' do
            expect(response).to have_http_status(:unprocessable_entity)
            safe_fields.each do |field|
              expect(span).to have_received(:set_tag).with(
                "safe_field.#{field}",
                inquiry_params[:inquiry][field]
              )
            end
          end

          it_behaves_like 'common error handling', :unprocessable_entity, 'service_error',
                          'InquiriesCreatorError: ' \
                          '{"Data":null,"Message":"Data Validation: missing InquiryCategory"' \
                          ',"ExceptionOccurred":true,"ExceptionMessage":"Data Validation: missing' \
                          'InquiryCategory","MessageId":"cb0dd954-ef25-4e56-b0d9-41925e5a190c"}'
        end
      end
    end
  end

  describe 'POST #create_reply' do
    let(:payload) { { 'reply' => 'this is my reply', 'files' => [{ 'file_name' => nil, 'file_content' => nil }] } }

    context 'when successful' do
      before do
        allow_any_instance_of(Crm::Service).to receive(:call).and_return({ Data: { Id: '123' } })
        sign_in(authorized_user)
        post '/ask_va_api/v0/inquiries/123/reply/new', params: payload
      end

      it 'returns status 200' do
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when crm api fail' do
      context 'when the API call fails' do
        let(:endpoint) { 'inquiries/123/reply/new' }
        let(:body) do
          '{"Data":null,"Message":"Data Validation: Missing Reply"' \
            ',"ExceptionOccurred":true,"ExceptionMessage":"Data Validation: ' \
            'Missing Reply","MessageId":"e2cbe041-df91-41f4-8bd2-8b6d9dbb2e38"}'
        end
        let(:failure) { Faraday::Response.new(response_body: body, status: 400) }

        before do
          sign_in(authorized_user)
          allow_any_instance_of(Crm::Service).to receive(:call)
            .with(endpoint:, method: :put,
                  payload: { Reply: 'this is my reply', ListOfAttachments: nil }).and_return(failure)
          post '/ask_va_api/v0/inquiries/123/reply/new', params: payload
        end

        it 'raise InquiriesCreatorError' do
          expect(response).to have_http_status(:unprocessable_entity)
        end

        it_behaves_like 'common error handling', :unprocessable_entity, 'service_error',
                        'AskVAApi::Correspondences::CorrespondencesCreatorError: ' \
                        '{"Data":null,"Message":"Data Validation: Missing Reply"' \
                        ',"ExceptionOccurred":true,"ExceptionMessage":"Data Validation: ' \
                        'Missing Reply","MessageId":"e2cbe041-df91-41f4-8bd2-8b6d9dbb2e38"}'
      end
    end
  end
end
