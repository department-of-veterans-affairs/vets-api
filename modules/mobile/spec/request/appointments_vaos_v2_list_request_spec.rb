# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/iam_session_helper'
require_relative '../support/matchers/json_schema_matcher'

RSpec.describe 'vaos v2 appointments', type: :request do
  include JsonSchemaMatchers

  before do
    iam_sign_in(build(:iam_user))
    allow_any_instance_of(IAMUser).to receive(:icn).and_return('1012846043V576341')
    allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token')
  end

  before(:all) do
    @original_cassette_dir = VCR.configure(&:cassette_library_dir)
    VCR.configure { |c| c.cassette_library_dir = 'modules/mobile/spec/support/vcr_cassettes' }
  end

  let(:mock_clinic) do
    mock_clinic = {
      service_name: 'Friendly Name Optometry'
    }

    allow_any_instance_of(Mobile::V2::Appointments::Proxy).to receive(:get_clinic).and_return(mock_clinic)
  end

  let(:mock_facility) do
    mock_facility = { id: '442',
                      name: 'Cheyenne VA Medical Center',
                      physical_address: { type: 'physical',
                                          line: ['2360 East Pershing Boulevard'],
                                          city: 'Cheyenne',
                                          state: 'WY',
                                          postal_code: '82001-5356' },
                      lat: 41.148026,
                      long: -104.786255,
                      phone: { main: '307-778-7550' },
                      url: nil,
                      code: nil }

    allow_any_instance_of(Mobile::V2::Appointments::Proxy).to receive(:get_facility).and_return(mock_facility)
  end

  after(:all) { VCR.configure { |c| c.cassette_library_dir = @original_cassette_dir } }

  describe 'GET /mobile/v0/appointments' do
    before do
      Flipper.enable(:mobile_appointment_use_VAOS_v2)
      Timecop.freeze(Time.zone.parse('2022-01-01T19:25:00Z'))
    end

    after do
      Flipper.disable(:mobile_appointment_use_VAOS_v2)
      Timecop.return
    end

    let(:start_date) { Time.zone.parse('2021-01-01T00:00:00Z').iso8601 }
    let(:end_date) { Time.zone.parse('2023-01-01T00:00:00Z').iso8601 }
    let(:params) { { startDate: start_date, endDate: end_date } }

    context 'request VAOS v2 VA appointment' do
      before do
        mock_facility
        mock_clinic
      end

      it 'returned appointment is identical to VAOS v0 version' do
        VCR.use_cassette('appointments/VAOS_v2/get_appointment_200',
                         match_requests_on: %i[method uri]) do
          get '/mobile/v0/appointments', headers: iam_headers, params: params
        end
        appt_v0_cancelled = JSON.parse(File.read(Rails.root.join('modules', 'mobile', 'spec', 'support',
                                                                 'fixtures', 'va_v0_appointment.json')))
        response_v2 = response.parsed_body.dig('data', 0)

        expect(response.body).to match_json_schema('appointments')

        # removed vetextId due to lack of use on FE
        expect(response_v2['attributes'].except('vetextId')).to eq(appt_v0_cancelled['attributes'].except('vetextId'))
      end
    end

    context 'request all appointments' do
      before do
        mock_facility
        mock_clinic
      end

      let(:start_date) { Time.zone.parse('1991-01-01T00:00:00Z').iso8601 }
      let(:end_date) { Time.zone.parse('2023-01-01T00:00:00Z').iso8601 }
      let(:params) { { page: { number: 1, size: 9999 }, startDate: start_date, endDate: end_date } }

      it 'processes all appointments without error' do
        VCR.use_cassette('appointments/VAOS_v2/get_all_appointment_200_ruben',
                         match_requests_on: %i[method uri]) do
          get '/mobile/v0/appointments', headers: iam_headers, params: params
        end
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['data'].size).to eq(1233)

        # VAOS v2 appointment is only different from appointments by allowing some fields to be nil.
        # This is due to bad staging data.
        expect(response.body).to match_json_schema('VAOS_v2_appointments')
      end
    end
  end
end
