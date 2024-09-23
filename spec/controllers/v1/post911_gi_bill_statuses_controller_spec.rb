# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/benefits_education/service'
require 'lighthouse/benefits_education/outside_working_hours'

RSpec.describe V1::Post911GIBillStatusesController, type: :controller do
  let(:user) { FactoryBot.create(:user, :loa3, icn: '1000000000V100000') }
  let(:once) { { times: 1, value: 1 } }
  let(:tz) { ActiveSupport::TimeZone.new(BenefitsEducation::Service::OPERATING_ZONE) }
  let(:noon) { tz.parse('1st Feb 2018 12:00:00') }

  before { sign_in_as(user) }

  context 'inside working hours' do
    before do
      allow(BenefitsEducation::Service).to receive(:within_scheduled_uptime?).and_return(true)
    end

    it 'returns a 200 success' do
      # valid icn retrieved from
      # https://github.com/department-of-veterans-affairs/vets-api-clients/blob/master/test_accounts/benefits_test_accounts.md
      # 001	Tamara	E	Ellis	F	6/19/67	796130115	1012667145V762142
      valid_user = FactoryBot.create(:user, :loa3, icn: '1012667145V762142')
      sign_in_as(valid_user)

      VCR.use_cassette('lighthouse/benefits_education/gi_bill_status/200_response') do
        expect(StatsD).to receive(:increment).with(V1::Post911GIBillStatusesController::STATSD_GI_BILL_TOTAL_KEY)
        expect(StatsD).to receive(:increment).with(
          "api.external_http_request.#{BenefitsEducation::Configuration.instance.service_name}.success", 1, anything
        )
        get :show
      end

      expect(response).to have_http_status(:ok)
      response_body = JSON.parse(response.body)['data']['attributes']

      # assertions that the data returned will not be empty strings
      expect(response_body['first_name']).not_to be_empty
      expect(response_body['last_name']).not_to be_empty
      expect(response_body['date_of_birth']).not_to be_empty
      expect(response_body['delimiting_date']).not_to be_empty
      expect(response_body['eligibility_date']).not_to be_empty
      expect(response_body['enrollments'][0]['begin_date']).not_to be_empty
      expect(response_body['enrollments'][0]['end_date']).not_to be_empty
    end

    it 'returns a 404 when vet isn\'t found' do
      VCR.use_cassette('lighthouse/benefits_education/gi_bill_status/404_response') do
        expect(StatsD).to receive(:increment).with(V1::Post911GIBillStatusesController::STATSD_GI_BILL_FAIL_KEY,
                                                   tags: ['error:404'])
        expect(StatsD).to receive(:increment).with(V1::Post911GIBillStatusesController::STATSD_GI_BILL_TOTAL_KEY)
        expect do
          get :show
        end.to change(PersonalInformationLog, :count)
      end

      expect(response).to have_http_status(:not_found)
      json_response = JSON.parse(response.body)
      error = json_response['errors'][0]
      expect(error['title']).to eq('Not Found')
      expect(error['detail']).to eq('Icn not found.')
    end
  end

  # TO-DO: Remove this suite of tests after transition of LTS to 24/7 availability
  context 'outside working hours' do
    # midnight
    before do
      Flipper.disable(:sob_updated_design)
      Timecop.freeze(tz.parse('2nd Feb 1993 00:00:00'))
    end
    after { Timecop.return }

    it 'returns 503' do
      get :show
      expect(response).to have_http_status(:service_unavailable)
    end

    it 'includes a Retry-After header' do
      get :show
      expect(response.headers).to include('Retry-After')
    end

    it 'ignores OutsideWorkingHours exception' do
      expect(Sentry).not_to receive(:capture_message)
      get :show
    end
  end

  context 'when Breakers::OutageException is raised' do
    let(:mock_service) do
      instance_double(
        Breakers::Service,
        name: 'Test Service'
      )
    end
    let(:mock_outage) do
      instance_double(
        Breakers::Outage,
        start_time: Time.zone.now,
        end_time: nil,
        service: mock_service
      )
    end

    let(:mock_exception) { Breakers::OutageException.new(mock_outage, mock_service) }

    before do
      allow_any_instance_of(BenefitsEducation::Configuration).to receive(:get).and_raise(mock_exception)
    end

    it 'returns a 503 status code' do
      get :show
      expect(response).to have_http_status(:service_unavailable)

      json = JSON.parse(response.body)
      expect(json['errors'][0]['status']).to eq('503')
    end
  end
end
