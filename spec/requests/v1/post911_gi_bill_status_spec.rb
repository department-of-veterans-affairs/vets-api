# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V1::Post911GIBillStatus', type: :request do
  include SchemaMatchers

  let(:tz) { ActiveSupport::TimeZone.new(BenefitsEducation::Service::OPERATING_ZONE) }
  let(:noon) { tz.parse('1st Feb 2018 12:00:00') }
  let(:midnight) { tz.parse('15th Mar 2018 00:00:00') }
  let(:user) { create(:user, icn: '1012667145V762142') }

  before do
    sign_in_as(user)
    allow(Settings.evss).to receive(:mock_gi_bill_status).and_return(false)
  end

  # TO-DO: Rename context after transition of LTS to 24/7 availability
  context 'inside working hours' do
    before { Timecop.freeze(noon) }

    after { Timecop.return }

    context 'with a 200 response' do
      it 'GET /v1/post911_gi_bill_status returns proper json' do
        VCR.use_cassette('lighthouse/benefits_education/gi_bill_status/200_response') do
          get v1_post911_gi_bill_status_url, params: nil
          expect(response).to match_response_schema('post911_gi_bill_status')
          assert_response :success
        end
      end
    end
  end

  # TO-DO: Remove context after transition of LTS to 24/7 availability
  context 'outside working hours' do
    before { Timecop.freeze(midnight) }

    after { Timecop.return }

    it 'returns 503' do
      get v1_post911_gi_bill_status_url, params: nil
      expect(response).to have_http_status(:service_unavailable)
    end

    it 'includes a Retry-After header' do
      get v1_post911_gi_bill_status_url, params: nil
      expect(response.headers).to include('Retry-After')
    end

    it 'ignores OutsideWorkingHours exception' do
      expect(Sentry).not_to receive(:capture_message)
      get v1_post911_gi_bill_status_url, params: nil
    end
  end

  context 'with deprecated GibsNotFoundUser class' do
    it 'loads the class for coverage', skip: 'No expectation in this example' do
      GibsNotFoundUser
    end
  end
end
