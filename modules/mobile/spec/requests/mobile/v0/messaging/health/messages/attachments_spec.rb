# frozen_string_literal: true

require_relative '../../../../../../support/helpers/rails_helper'

RSpec.describe 'Mobile::V0::Messaging::Health::Messages::Attachments', :skip_json_api_validation, type: :request do
  let!(:user) { sis_user(:mhv, mhv_account_type: 'Premium') }
  let(:user_id) { '10616687' }
  let(:inbox_id) { 0 }
  let(:message_id) { 573_302 }

  before do
    Timecop.freeze(Time.zone.parse('2017-05-01T19:25:00Z'))
  end

  after do
    Timecop.return
  end

  context 'when not authorized' do
    it 'responds with 403 error' do
      VCR.use_cassette('mobile/messages/session_error') do
        get '/mobile/v0/messaging/health/messages/629999/attachments/629993', headers: sis_headers
      end
      expect(response).not_to be_successful
      expect(response).to have_http_status(:forbidden)
    end
  end

  context 'when authorized' do
    before do
      VCR.insert_cassette('sm_client/session')
    end

    after do
      VCR.eject_cassette
    end

    describe '#show' do
      it 'responds sending data for an attachment' do
        VCR.use_cassette('sm_client/messages/nested_resources/gets_a_single_attachment_by_id') do
          get '/mobile/v0/messaging/health/messages/629999/attachments/629993', headers: sis_headers
        end
        expect(response).to be_successful
        expect(response.headers['Content-Disposition'])
          .to eq("attachment; filename=\"noise300x200.png\"; filename*=UTF-8''noise300x200.png")
        expect(response.headers['Content-Transfer-Encoding']).to eq('binary')
        expect(response.headers['Content-Type']).to eq('image/png')
        expect(response.body).to be_a(String)
      end
    end
  end
end
