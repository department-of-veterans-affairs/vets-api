# frozen_string_literal: true
require 'rails_helper'

RSpec.describe V0::Post911GIBillStatusesController, type: :controller do
  include SchemaMatchers

  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:session) { Session.create(uuid: user.uuid) }

  let(:once) { { times: 1, value: 1 } }

  context 'without mocked responses' do
    before do
      Settings.evss.mock_gi_bill_status = false
    end

    gi_bill_200 = { cassette_name: 'evss/gi_bill_status/gi_bill_status' }
    context 'when EVSS response is 403', vcr: gi_bill_200 do
      it 'should have a response that matches the schema' do
        request.headers['Authorization'] = "Token token=#{session.token}"
        get :show
        expect(response).to have_http_status(:ok)
        expect(response).to match_response_schema('post911_gi_bill_status', strict: false)
      end

      it 'does not increment the fail counter' do
        request.headers['Authorization'] = "Token token=#{session.token}"
        expect { get :show }
          .not_to trigger_statsd_increment(described_class::STATSD_GI_BILL_FAIL_KEY)
      end

      it 'increments the total counter' do
        request.headers['Authorization'] = "Token token=#{session.token}"
        expect { get :show }
          .to trigger_statsd_increment(described_class::STATSD_GI_BILL_TOTAL_KEY, **once)
      end
    end

    # this cassette was copied from 'gi_bill_status_500' and manually edited to contain
    # the 'education.chapter33claimant.partner.service.down' error because the EVSS CI
    # environment is not capable of returning this error
    gi_bill_500 = { cassette_name: 'evss/gi_bill_status/gi_bill_status_500_with_err_msg' }
    context 'when EVSS response is 500 with an error message', vcr: gi_bill_500 do
      it 'should respond with 503' do
        request.headers['Authorization'] = "Token token=#{session.token}"
        get :show
        expect(response).to have_http_status(:service_unavailable)
      end
    end

    gi_bill_unauthorized = { cassette_name: 'evss/gi_bill_status/unauthorized' }
    context 'when EVSS response is http-500 unauthorized', vcr: gi_bill_unauthorized do
      it 'should respond with 403' do
        request.headers['Authorization'] = "Token token=#{session.token}"
        get :show
        expect(response).to have_http_status(:forbidden)
      end
    end

    gi_bill_404 = { cassette_name: 'evss/gi_bill_status/vet_not_found' }
    describe 'when EVSS has no knowledge of user', vcr: gi_bill_404 do
      # special EVSS CI user ssn=796066619
      let(:user) { FactoryBot.create(:user, :loa3, ssn: '796066619', uuid: 'ertydfh456') }
      let(:session) { Session.create(uuid: user.uuid) }

      it 'responds with 404' do
        request.headers['Authorization'] = "Token token=#{session.token}"
        get :show
        expect(response).to have_http_status(:not_found)
      end

      it 'increments the statsd total and fail counters' do
        request.headers['Authorization'] = "Token token=#{session.token}"
        vet_not_found_tag = ['error:vet_not_found']
        expect { get :show }
          .to trigger_statsd_increment(described_class::STATSD_GI_BILL_FAIL_KEY, tags: vet_not_found_tag, **once)
          .and trigger_statsd_increment(described_class::STATSD_GI_BILL_TOTAL_KEY, **once)
      end
    end
    describe 'when EVSS has no info of user' do
      # special EVSS CI user ssn=796066622
      let(:user) { FactoryBot.create(:user, :loa3, ssn: '796066622', uuid: 'fghj3456') }
      let(:session) { Session.create(uuid: user.uuid) }
      it 'renders nil data' do
        VCR.use_cassette('evss/gi_bill_status/vet_with_no_info') do
          request.headers['Authorization'] = "Token token=#{session.token}"
          get :show
          expect(response).to have_http_status(:not_found)
        end
      end
    end

    describe 'when EVSS partners return invalid data' do
      # special EVSS CI user ssn=301010304
      let(:user) { FactoryBot.create(:user, :loa3, ssn: '301010304', uuid: 'aaaa1a') }
      let(:session) { Session.create(uuid: user.uuid) }
      it 'responds with a 422' do
        VCR.use_cassette('evss/gi_bill_status/invalid_partner_data') do
          request.headers['Authorization'] = "Token token=#{session.token}"
          get :show
          expect(response).to have_http_status(:service_unavailable)
        end
      end
    end
  end
end
