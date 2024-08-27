# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AskVAApi StaticData', type: :request do
  let(:logger) { instance_double(LogService) }
  let(:span) { instance_double(Datadog::Tracing::Span) }

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

  describe 'GET #announcements' do
    let(:announcements_path) { '/ask_va_api/v0/announcements' }
    let(:expected_hash) do
      {
        'id' => nil,
        'type' => 'announcements',
        'attributes' => {
          'text' => 'Test',
          'start_date' => '8/18/2024 1:00:00 PM',
          'end_date' => '8/18/2024 1:00:00 PM',
          'is_portal' => false
        }
      }
    end

    context 'when successful' do
      before do
        get announcements_path, params: { user_mock_data: true }
      end

      it 'returns announcements data' do
        expect(JSON.parse(response.body)['data']).to include(a_hash_including(expected_hash))
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when an error occurs' do
      let(:service) { instance_double(Crm::Service) }
      let(:body) do
        '{"Data":null,"Message"' \
          ':"Data Validation: No Announcements Posted with End Date Greater than 8/5/2024 5:49:23 PM"' \
          ',"ExceptionOccurred":true,"ExceptionMessage"' \
          ':"Data Validation: No Announcements Posted with End Date Greater than 8/5/2024 5:49:23 PM"' \
          ',"MessageId":"b8b6e029-bbea-4451-9ce1-5bd8e2b04520"}'
      end
      let(:failure) { Faraday::Response.new(response_body: body, status: 400) }

      before do
        allow_any_instance_of(Crm::CrmToken).to receive(:call).and_return('token')
        allow(Crm::Service).to receive(:new).and_return(service)
        allow(service).to receive(:call).and_return(failure)
        get announcements_path
      end

      it_behaves_like 'common error handling', :unprocessable_entity, 'service_error',
                      'AskVAApi::Announcements::AnnouncementsRetrieverError: {"Data":null,"Message"' \
                      ':"Data Validation: No Announcements Posted with End Date Greater than 8/5/2024 5:49:23 PM"' \
                      ',"ExceptionOccurred":true,"ExceptionMessage"' \
                      ':"Data Validation: No Announcements Posted with End Date Greater than 8/5/2024 5:49:23 PM"' \
                      ',"MessageId":"b8b6e029-bbea-4451-9ce1-5bd8e2b04520"}'
    end
  end

  describe 'GET #branch_of_service' do
    context 'when successful' do
      before do
        allow_any_instance_of(ClaimsApi::BRD).to receive(:service_branches).and_return(
          [{ code: 'USMA', description: 'US Military Academy' },
           { code: 'MM', description: 'Merchant Marine' },
           { code: 'AF', description: 'Air Force' },
           { code: 'ARMY', description: 'Army' },
           { code: 'AFR', description: 'Air Force Reserves' },
           { code: 'PHS', description: 'Public Health Service' },
           { code: 'AAC', description: 'Army Air Corps or Army Air Force' },
           { code: 'WAC', description: "Women's Army Corps" },
           { code: 'NOAA', description: 'National Oceanic & Atmospheric Administration' },
           { code: 'SF', description: 'Space Force' },
           { code: 'NAVY', description: 'Navy' },
           { code: 'N ACAD', description: 'Naval Academy' },
           { code: 'OTH', description: 'Other' },
           { code: 'ARNG', description: 'Army National Guard' },
           { code: 'CG', description: 'Coast Guard' },
           { code: 'MC', description: 'Marine Corps' },
           { code: 'AR', description: 'Army Reserves' },
           { code: 'CGR', description: 'Coast Guard Reserves' },
           { code: 'MCR', description: 'Marine Corps Reserves' },
           { code: 'NR', description: 'Navy Reserves' },
           { code: 'ANG', description: 'Air National Guard' },
           { code: 'AF ACAD', description: 'Air Force Academy' },
           { code: 'CG ACAD', description: 'Coast Guard Academy' }]
        )
        get '/ask_va_api/v0//branch_of_service'
      end

      it 'returns http status :ok' do
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe 'GET #categories' do
    let(:categories_path) { '/ask_va_api/v0/categories' }
    let(:expected_hash) do
      { 'id' => '75524deb-d864-eb11-bb24-000d3a579c45',
        'type' => 'categories',
        'attributes' =>
         { 'name' => 'Education (Ch.30, 33, 35, 1606, etc. & Work Study)',
           'allow_attachments' => true,
           'description' => nil,
           'display_name' => 'Education (Ch.30, 33, 35, 1606, etc. & Work Study)',
           'parent_id' => nil,
           'rank_order' => 1,
           'requires_authentication' => true } }
    end

    context 'when successful' do
      before do
        get categories_path, params: { user_mock_data: true }
      end

      it 'returns categories data' do
        expect(JSON.parse(response.body)['data']).to include(a_hash_including(expected_hash))
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when an error occurs' do
      let(:error_message) { 'service error' }

      before do
        allow_any_instance_of(Crm::CacheData)
          .to receive(:call)
          .and_raise(StandardError)
        get categories_path
      end

      it_behaves_like 'common error handling', :unprocessable_entity, 'service_error',
                      'StandardError: StandardError'
    end
  end

  describe 'GET #Topics' do
    let(:category) do
      AskVAApi::Categories::Entity.new({ Id: '60524deb-d864-eb11-bb24-000d3a579c45' })
    end
    let(:expected_response) do
      { 'id' => 'a72a8586-e764-eb11-bb23-000d3a579c3f', 'type' => 'topics',
        'attributes' => { 'name' => 'Board Appeals', 'allow_attachments' => false, 'description' => nil,
                          'display_name' => 'Board Appeals', 'parent_id' => '60524deb-d864-eb11-bb24-000d3a579c45',
                          'rank_order' => 0, 'requires_authentication' => false } }
    end
    let(:topics_path) { "/ask_va_api/v0/categories/#{category.id}/topics" }

    context 'when successful' do
      before { get topics_path, params: { user_mock_data: true } }

      it 'returns topics data' do
        expect(JSON.parse(response.body)['data']).to include(a_hash_including(expected_response))
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when an error occurs' do
      let(:error_message) { 'service error' }

      before do
        allow_any_instance_of(Crm::CacheData)
          .to receive(:call)
          .and_raise(StandardError)
        get topics_path
      end

      it_behaves_like 'common error handling', :unprocessable_entity, 'service_error',
                      'StandardError: StandardError'
    end
  end

  describe 'GET #SubTopics' do
    let(:topic) do
      AskVAApi::Topics::Entity.new({ Id: 'f0ba9562-e864-eb11-bb23-000d3a579c44' })
    end
    let(:expected_response) do
      { 'id' => '7b2dbcee-eb64-eb11-bb23-000d3a579b83', 'type' => 'sub_topics',
        'attributes' => { 'name' => 'Accessing a webpage on VA.gov', 'allow_attachments' => false,
                          'description' => nil, 'display_name' => 'Accessing a webpage on VA.gov',
                          'parent_id' => 'f0ba9562-e864-eb11-bb23-000d3a579c44', 'rank_order' => 0,
                          'requires_authentication' => false } }
    end
    let(:subtopics_path) { "/ask_va_api/v0/topics/#{topic.id}/subtopics" }

    context 'when successful' do
      before { get subtopics_path, params: { user_mock_data: true } }

      it 'returns subtopics data' do
        expect(JSON.parse(response.body)['data']).to include(a_hash_including(expected_response))
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when an error occurs' do
      let(:error_message) { 'service error' }

      before do
        allow_any_instance_of(AskVAApi::SubTopics::Retriever)
          .to receive(:call)
          .and_raise(StandardError, 'standard error')
        get subtopics_path, params: { mock: true }
      end

      it_behaves_like 'common error handling', :internal_server_error, 'unexpected_error',
                      'standard error'
    end
  end

  describe 'GET #optionset' do
    let(:optionset) do
      AskVAApi::Optionset::Entity.new({ Id: 'f0ba9562-e864-eb11-bb23-000d3a579c44' })
    end
    let(:expected_response) do
      {
        'id' => '722310000',
        'type' => 'optionsets',
        'attributes' => {
          'name' => 'Air Force'
        }
      }
    end
    let(:optionset_path) { '/ask_va_api/v0/optionset' }

    context 'when successful' do
      before { get optionset_path, params: { user_mock_data: true, name: 'branchofservice' } }

      it 'returns optionset data' do
        expect(JSON.parse(response.body)['data']).to include(a_hash_including(expected_response))
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when an error occurs' do
      let(:body) do
        '{"Data":null,"Message":"Data Validation: Invalid OptionSet Name iris_branchofservic, valid' \
          ' values are iris_inquiryabout, iris_inquirysource, iris_inquirytype, iris_levelofauthentication,' \
          ' iris_suffix, iris_veteranrelationship, iris_branchofservice, iris_country, iris_province,' \
          ' iris_responsetype, iris_dependentrelationship, statuscode, iris_messagetype","ExceptionOccurred":' \
          'true,"ExceptionMessage":"Data Validation: Invalid OptionSet Name iris_branchofservic, valid' \
          ' values are iris_inquiryabout, iris_inquirysource, iris_inquirytype, iris_levelofauthentication,' \
          ' iris_suffix, iris_veteranrelationship, iris_branchofservice, iris_country, iris_province,' \
          ' iris_responsetype, iris_dependentrelationship, statuscode, iris_messagetype","MessageId":' \
          '"6dfa81bd-f04a-4f39-88c5-1422d88ed3ff"}'
      end
      let(:failure) { Faraday::Response.new(response_body: body, status: 400) }

      before do
        allow_any_instance_of(Crm::Service).to receive(:call)
          .with(endpoint: 'optionset', payload: { name: 'iris_branchofservic' }).and_return(failure)
        get optionset_path, params: { user_mock_data: nil, name: 'branchofservic' }
      end

      it_behaves_like 'common error handling', :unprocessable_entity, 'service_error',
                      'ErrorHandler::ServiceError: StandardError: {"Data":null,"Message":' \
                      '"Data Validation: Invalid OptionSet Name iris_branchofservic, ' \
                      'valid values are iris_inquiryabout, iris_inquirysource, iris_inquirytype,' \
                      ' iris_levelofauthentication, iris_suffix, iris_veteranrelationship,' \
                      ' iris_branchofservice, iris_country, iris_province, iris_responsetype,' \
                      ' iris_dependentrelationship, statuscode, iris_messagetype","ExceptionOccurred"' \
                      ':true,"ExceptionMessage":"Data Validation: Invalid OptionSet Name iris_branchofservic,' \
                      ' valid values are iris_inquiryabout, iris_inquirysource, iris_inquirytype,' \
                      ' iris_levelofauthentication, iris_suffix, iris_veteranrelationship, iris_branchofservice,' \
                      ' iris_country, iris_province, iris_responsetype, iris_dependentrelationship, statuscode,' \
                      ' iris_messagetype","MessageId":"6dfa81bd-f04a-4f39-88c5-1422d88ed3ff"}'
    end
  end

  describe 'GET #Zipcode' do
    let(:expected_response) do
      [{ 'id' => nil,
         'type' => 'zipcodes',
         'attributes' =>
          { 'zipcode' => '36010', 'city' => 'Autaugaville', 'state' => 'AL', 'lat' => 32.4312, 'lng' => -86.6549 } },
       { 'id' => nil,
         'type' => 'zipcodes',
         'attributes' => { 'zipcode' => '36011', 'city' => 'Millbrook', 'state' => 'AL', 'lat' => 32.5002,
                           'lng' => -86.3691 } },
       { 'id' => nil,
         'type' => 'zipcodes',
         'attributes' => { 'zipcode' => '36012', 'city' => 'Deatsville', 'state' => 'AL', 'lat' => 32.5997,
                           'lng' => -86.324 } }]
    end
    let(:zipcodes_path) { '/ask_va_api/v0/zipcodes' }

    context 'when successful' do
      before { get zipcodes_path, params: { zipcode: zip, mock: true } }

      context 'when zipcodes are found' do
        let(:zip) { '3601' }

        it 'returns zipcode data' do
          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)['data'].first(3)).to eq(expected_response)
        end
      end

      context 'when no zipcode is found' do
        let(:zip) { '4000' }

        it 'returns an empty array' do
          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)['data']).to eq([])
        end
      end
    end

    context 'when an error occurs' do
      let(:error_message) { 'standard error' }

      before do
        allow_any_instance_of(AskVAApi::Zipcodes::Retriever)
          .to receive(:fetch_data)
          .and_raise(StandardError.new(error_message))
        get zipcodes_path, params: { mock: true }
      end

      it_behaves_like 'common error handling', :unprocessable_entity, 'service_error',
                      'StandardError: standard error'
    end
  end

  describe 'GET #States' do
    let(:states_path) { '/ask_va_api/v0/states' }
    let(:scoped_response) do
      [
        { 'id' => nil, 'type' => 'states', 'attributes' => { 'name' => 'Alabama', 'code' => 'AL' } },
        { 'id' => nil, 'type' => 'states', 'attributes' => { 'name' => 'Alaska', 'code' => 'AK' } },
        { 'id' => nil, 'type' => 'states', 'attributes' => { 'name' => 'Arizona', 'code' => 'AZ' } }
      ]
    end

    context 'when successful' do
      before { get states_path, params: { mock: true } }

      it 'returns all the states' do
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['data'].first(3)).to eq(scoped_response)
      end
    end

    context 'when an error occurs' do
      let(:error_message) { 'standard error' }

      before do
        allow_any_instance_of(AskVAApi::States::Retriever)
          .to receive(:fetch_data)
          .and_raise(StandardError.new(error_message))
        get states_path, params: { mock: true }
      end

      it_behaves_like 'common error handling', :unprocessable_entity, 'service_error',
                      'StandardError: standard error'
    end
  end
end
