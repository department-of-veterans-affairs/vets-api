# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/iam_session_helper'
require_relative '../support/matchers/json_schema_matcher'

RSpec.describe 'appointments', type: :request do
  include JsonSchemaMatchers

  describe 'GET /mobile/v0/appointments' do
    before do
      iam_sign_in
      allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token')
      Timecop.freeze(Time.zone.parse('2020-11-01T10:30:00Z'))
    end

    after { Timecop.return }

    before(:all) do
      @original_cassette_dir = VCR.configure(&:cassette_library_dir)
      VCR.configure { |c| c.cassette_library_dir = 'modules/mobile/spec/support/vcr_cassettes' }
    end

    after(:all) { VCR.configure { |c| c.cassette_library_dir = @original_cassette_dir } }

    context 'with a user has mixed upcoming appointments' do
      before do
        VCR.use_cassette('appointments/get_facilities', match_requests_on: %i[method uri]) do
          VCR.use_cassette('appointments/get_cc_appointments', match_requests_on: %i[method uri]) do
            VCR.use_cassette('appointments/get_appointments', match_requests_on: %i[method uri]) do
              get '/mobile/v0/appointments', headers: iam_headers, params: params
            end
          end
        end
      end

      let(:start_date) { Time.now.utc.iso8601 }
      let(:end_date) { (Time.now.utc + 3.months).iso8601 }
      let(:params) { { start_date: start_date, end_date: end_date } }
      let(:first_appointment) { response.parsed_body['data'].first['attributes'] }
      let(:last_appointment) { response.parsed_body['data'].last['attributes'] }

      it 'returns an ok response' do
        expect(response).to have_http_status(:ok)
      end

      it 'matches the expected schema' do
        expect(response.body).to match_json_schema('appointments')
      end

      it 'sorts the appointments by startDateUtc ascending' do
        expect(first_appointment['startDateUtc']).to be < last_appointment['startDateUtc']
      end

      it 'includes the expected properties for a VA appointment' do
        va_appointment = response.parsed_body['data'].filter { |a| a['attributes']['appointmentType'] == 'VA' }.first
        expect(va_appointment).to include(
          {
            'type' => 'appointment',
            'attributes' => {
              'appointmentType' => 'VA',
              'comment' => nil,
              'facilityId' => '442',
              'healthcareService' => 'CHY PC KILPATRICK',
              'location' => {
                'name' => 'CHEYENNE VAMC',
                'address' => {
                  'street' => '2360 East Pershing Boulevard',
                  'city' => 'Cheyenne',
                  'state' => 'WY',
                  'zipCode' => '82001-5356'
                },
                'lat' => 41.148027,
                'long' => -104.7862575,
                'phone' => {
                  'areaCode' => nil,
                  'number' => nil,
                  'extension' => nil
                },
                'url' => nil,
                'code' => nil
              },
              'minutesDuration' => 20,
              'startDateLocal' => '2020-11-03T09:00:00.000-07:00',
              'startDateUtc' => '2020-11-03T16:00:00.000+00:00',
              'status' => 'BOOKED'
            }
          }
        )
      end

      it 'includes the expected properties for a CC appointment' do
        cc_appointment = response.parsed_body['data'].filter do |a|
          a['attributes']['appointmentType'] == 'COMMUNITY_CARE'
        end.first

        expect(cc_appointment).to include(
          {
            'type' => 'appointment',
            'attributes' => {
              'appointmentType' => 'COMMUNITY_CARE',
              'comment' => 'Test',
              'facilityId' => nil,
              'healthcareService' => 'AP',
              'location' => {
                'name' => 'AP',
                'address' => {
                  'street' => '2345, Oak Crest Cir',
                  'city' => 'Aldie',
                  'state' => 'VA',
                  'zipCode' => '20106'
                },
                'lat' => nil,
                'long' => nil,
                'phone' => {
                  'areaCode' => nil,
                  'number' => nil,
                  'extension' => nil
                },
                'url' => nil,
                'code' => nil
              },
              'minutesDuration' => 60,
              'startDateLocal' => '2020-01-10T13:00:00.000-05:00',
              'startDateUtc' => '2020-01-10T18:00:00.000Z',
              'status' => 'BOOKED'
            }
          }
        )
      end
    end
  end
end
