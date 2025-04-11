# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AskVAApi StaticData', type: :request do
  let(:logger) { instance_double(LogService) }
  let(:span) { instance_double(Datadog::Tracing::Span) }

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

  describe 'GET #contents' do
    let(:contents_path) { '/ask_va_api/v0/contents' }
    let(:expected_hash) do
      { 'id' => '75524deb-d864-eb11-bb24-000d3a579c45',
        'type' => 'contents',
        'attributes' =>
         { 'name' => 'Education benefits and work study',
           'allow_attachments' => true,
           'description' => nil,
           'display_name' => 'Education benefits and work study',
           'parent_id' => nil,
           'rank_order' => 1,
           'requires_authentication' => true,
           'topic_type' => 'Category',
           'contact_preferences' => ['Email'] } }
    end

    context 'when successful' do
      before do
        get contents_path, params: { user_mock_data: true, type: 'category' }
      end

      it 'returns contents data' do
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
        get contents_path, params: { type: 'category' }
      end

      it_behaves_like 'common error handling', :unprocessable_entity, 'service_error',
                      'StandardError: StandardError'
    end
  end
end
