# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::Post911GIBillStatusesController, type: :controller do
  include SchemaMatchers

  let(:user) { FactoryBot.create(:user, :loa3) }
  before { sign_in_as(user) }

  let(:once) { { times: 1, value: 1 } }

  let(:tz) { ActiveSupport::TimeZone.new(EVSS::GiBillStatus::Service::OPERATING_ZONE) }
  let(:noon) { tz.parse('1st Feb 2018 12:00:00') }

  context 'inside working hours' do
    before { Timecop.freeze(noon) }

    after { Timecop.return }

    context 'without mocked responses' do
      before do
        allow(Settings.evss).to receive(:mock_gi_bill_status).and_return(false)
      end

      gi_bill_200 = { cassette_name: 'evss/gi_bill_status/gi_bill_status' }
      context 'when EVSS response is 403', vcr: gi_bill_200 do
        it 'has a response that matches the schema' do
          get :show
          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('post911_gi_bill_status', strict: false)
        end

        it 'does not increment the fail counter' do
          expect { get :show }
            .not_to trigger_statsd_increment(described_class::STATSD_GI_BILL_FAIL_KEY)
        end

        it 'increments the total counter' do
          expect { get :show }
            .to trigger_statsd_increment(described_class::STATSD_GI_BILL_TOTAL_KEY, **once)
        end
      end

      # this cassette was copied from 'gi_bill_status_500' and manually edited to contain
      # the 'education.chapter33claimant.partner.service.down' error because the EVSS CI
      # environment is not capable of returning this error
      gi_bill_500 = { cassette_name: 'evss/gi_bill_status/gi_bill_status_500_with_err_msg' }
      context 'when EVSS response is 500 with an error message', vcr: gi_bill_500 do
        it 'responds with 503' do
          get :show
          expect(response).to have_http_status(:service_unavailable)
        end
      end

      gi_bill_unauthorized = { cassette_name: 'evss/gi_bill_status/unauthorized' }
      context 'when EVSS response is http-500 unauthorized', vcr: gi_bill_unauthorized do
        it 'responds with 403' do
          get :show
          expect(response).to have_http_status(:forbidden)
        end
      end

      gi_bill404 = { cassette_name: 'evss/gi_bill_status/vet_not_found' }
      describe 'when EVSS has no knowledge of user', vcr: gi_bill404 do
        # special EVSS CI user ssn=796066619
        let(:user) { FactoryBot.create(:user, :loa3, ssn: '796066619', uuid: '89b40886-95e3-4a5b-824e-a4658b707507') }

        it 'responds with 404' do
          get :show
          expect(response).to have_http_status(:not_found)
        end

        it 'logs a record' do
          expect { get :show }.to change(PersonalInformationLog, :count).by(1)
        end

        it 'increments the statsd total and fail counters' do
          vet_not_found_tag = ['error:vet_not_found']
          expect { get :show }
            .to trigger_statsd_increment(described_class::STATSD_GI_BILL_FAIL_KEY, tags: vet_not_found_tag, **once)
            .and trigger_statsd_increment(described_class::STATSD_GI_BILL_TOTAL_KEY, **once)
        end
      end

      describe 'when EVSS has no info of user' do
        # special EVSS CI user ssn=796066622
        let(:user) { FactoryBot.create(:user, :loa3, ssn: '796066622', uuid: '89b40886-95e3-4a5b-824e-a4658b707508') }

        it 'renders nil data' do
          VCR.use_cassette('evss/gi_bill_status/vet_with_no_info') do
            get :show
            expect(response).to have_http_status(:not_found)
          end
        end
      end

      describe 'when EVSS returns invalid user info' do
        # special EVSS CI user ssn=796066622
        let(:user) { FactoryBot.create(:user, :loa3, ssn: '796066622', uuid: '89b40886-95e3-4a5b-824e-a4658b707508') }

        it 'responds with a 500' do
          VCR.use_cassette('evss/gi_bill_status/vet_with_invalid_info') do
            get :show
            expect(response).to have_http_status(:error)
          end
        end
      end

      describe 'when EVSS partners return invalid data' do
        # special EVSS CI user ssn=301010304
        let(:user) { FactoryBot.create(:user, :loa3, ssn: '301010304', uuid: 'aaaa1a') }

        it 'responds with a 422' do
          VCR.use_cassette('evss/gi_bill_status/invalid_partner_data') do
            get :show
            expect(response).to have_http_status(:service_unavailable)
          end
        end
      end
    end
  end
end
