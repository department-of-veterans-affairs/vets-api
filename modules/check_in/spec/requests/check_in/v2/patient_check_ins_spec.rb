# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'CheckIn::V2::PatientCheckIns', type: :request do
  let(:id) { '5bcd636c-d4d3-4349-9058-03b2f6b38ced' }
  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }

  before do
    allow(Rails).to receive(:cache).and_return(memory_store)
    allow(Flipper).to receive(:enabled?).with('check_in_experience_enabled').and_return(true)
    allow(Flipper).to receive(:enabled?).with('check_in_experience_mock_enabled').and_return(false)

    Rails.cache.clear
  end

  describe 'GET `show`' do
    context 'when JWT token and Redis entries are absent' do
      let(:resp) do
        {
          'permissions' => 'read.none',
          'status' => 'success',
          'uuid' => id
        }
      end

      it 'returns unauthorized status' do
        get "/check_in/v2/patient_check_ins/#{id}"

        expect(response).to have_http_status(:unauthorized)
      end

      it 'returns read.none permissions' do
        get "/check_in/v2/patient_check_ins/#{id}"

        expect(JSON.parse(response.body)).to eq(resp)
      end
    end

    context 'when the session is authorized' do
      let(:next_of_kin1) do
        {
          'name' => 'Joe',
          'workPhone' => '564-438-5739',
          'relationship' => 'Brother',
          'phone' => '738-573-2849',
          'address' => {
            'street1' => '432 Horner Street',
            'street2' => 'Apt 53',
            'street3' => '',
            'city' => 'Akron',
            'county' => 'OH',
            'state' => 'OH',
            'zip' => '44308',
            'zip4' => '4252',
            'country' => 'USA'
          }
        }
      end
      let(:emergency_contact) do
        {
          'name' => 'Michael',
          'relationship' => 'Spouse',
          'phone' => '415-322-9968',
          'workPhone' => '630-835-1623',
          'address' => {
            'street1' => '3008 Millbrook Road',
            'street2' => '',
            'street3' => '',
            'city' => 'Wheeling',
            'county' => 'IL',
            'state' => 'IL',
            'zip' => '60090',
            'zip4' => '7241',
            'country' => 'USA'
          }
        }
      end
      let(:mailing_address) do
        {
          'street1' => '1025 Meadowbrook Mall Road',
          'street2' => '',
          'street3' => '',
          'city' => 'Beverly Hills',
          'county' => 'Los Angeles',
          'state' => 'CA',
          'zip' => '60090',
          'zip4' => nil,
          'country' => 'USA'
        }
      end
      let(:home_address) do
        {
          'street1' => '3899 Southside Lane',
          'street2' => '',
          'street3' => '',
          'city' => 'Los Angeles',
          'county' => 'Los Angeles',
          'state' => 'CA',
          'zip' => '90017',
          'zip4' => nil,
          'country' => 'USA'
        }
      end
      let(:home_phone) { '323-743-2569' }
      let(:mobile_phone) { '323-896-8512' }
      let(:work_phone) { '909-992-3911' }
      let(:email_address) { 'utilside@goggleappsmail.com' }
      let(:demographics) do
        {
          'nextOfKin1' => next_of_kin1,
          'emergencyContact' => emergency_contact,
          'mailingAddress' => mailing_address,
          'homeAddress' => home_address,
          'homePhone' => home_phone,
          'mobilePhone' => mobile_phone,
          'workPhone' => work_phone,
          'emailAddress' => email_address
        }
      end
      let(:appointment1) do
        {
          'appointmentIEN' => '460',
          'checkedInTime' => '',
          'checkInSteps' => {},
          'checkInWindowEnd' => '2021-12-23T08:40:00.000-05:00',
          'checkInWindowStart' => '2021-12-23T08:00:00.000-05:00',
          'clinicCreditStopCodeName' => 'SOCIAL WORK SERVICE',
          'clinicFriendlyName' => 'Health Wellness',
          'clinicIen' => 500,
          'clinicLocation' => 'ATLANTA VAMC',
          'clinicName' => 'Family Wellness',
          'clinicPhoneNumber' => '555-555-5555',
          'clinicStopCodeName' => 'PRIMARY CARE/MEDICINE',
          'doctorName' => '',
          'eligibility' => 'ELIGIBLE',
          'facility' => 'VEHU DIVISION',
          'kind' => 'clinic',
          'startTime' => '2021-12-23T08:30:00',
          'stationNo' => 500,
          'status' => ''
        }
      end
      let(:patient_demographic_status) do
        {
          'demographicsNeedsUpdate' => true,
          'demographicsConfirmedAt' => nil,
          'nextOfKinNeedsUpdate' => false,
          'nextOfKinConfirmedAt' => '2021-12-10T05:15:00.000-05:00',
          'emergencyContactNeedsUpdate' => true,
          'emergencyContactConfirmedAt' => '2021-12-10T05:30:00.000-05:00'
        }
      end
      let(:resp) do
        {
          'id' => id,
          'payload' => {
            'address' => nil,
            'demographics' => demographics,
            'appointments' => [appointment1],
            'patientDemographicsStatus' => patient_demographic_status,
            'setECheckinStartedCalled' => false
          }
        }
      end
      let(:session_params) do
        {
          params: {
            session: {
              uuid: id,
              dob: '1960-03-12',
              last_name: 'Johnson'
            }
          }
        }
      end

      it 'returns valid response' do
        VCR.use_cassette 'check_in/lorota/token/token_200' do
          post '/check_in/v2/sessions', **session_params
          expect(response).to have_http_status(:ok)
        end

        VCR.use_cassette('check_in/lorota/data/data_200', match_requests_on: [:host]) do
          VCR.use_cassette 'check_in/chip/set_echeckin_started/set_echeckin_started_200' do
            VCR.use_cassette 'check_in/chip/token/token_200' do
              get "/check_in/v2/patient_check_ins/#{id}"
            end
          end
        end
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq(resp)
      end

      context 'for OH sites' do
        let(:appointment) do
          {
            'appointmentIEN' => '4822366',
            'clinicCreditStopCodeName' => '',
            'clinicFriendlyName' => 'Endoscopy',
            'clinicIen' => '32216049',
            'clinicLocation' => '',
            'clinicName' => 'Endoscopy',
            'clinicPhoneNumber' => '909-825-7084',
            'clinicStopCodeName' => 'Mental Health, Primary Care',
            'doctorName' => 'Dr. Jones',
            'facility' => 'Jerry L. Pettis Memorial Veterans Hospital',
            'facilityAddress' => {
              'city' => 'Loma Linda',
              'state' => 'CA',
              'street1' => '',
              'street2' => '',
              'street3' => '',
              'zip' => '92357-1000'
            },
            'kind' => 'clinic',
            'startTime' => '2024-02-14T22:10:00.000+00:00',
            'stationNo' => '530',
            'status' => 'Confirmed',
            'timezone' => 'America/Los_Angeles'
          }
        end
        let(:resp) do
          {
            'id' => id,
            'payload' => {
              'address' => '1166 6th Avenue 22, New York, NY 23423 US',
              'demographics' => {},
              'appointments' => [appointment],
              'patientDemographicsStatus' => {},
              'setECheckinStartedCalled' => nil
            }
          }
        end

        it 'does not call set_echeckin_started' do
          VCR.use_cassette 'check_in/lorota/token/token_200' do
            post '/check_in/v2/sessions', **session_params
            expect(response).to have_http_status(:ok)
          end

          VCR.use_cassette('check_in/lorota/data/data_oracle_health_200', match_requests_on: [:host]) do
            VCR.use_cassette 'check_in/chip/token/token_200' do
              get "/check_in/v2/patient_check_ins/#{id}?facilityType=oh"
            end
          end
          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)).to eq(resp)
        end
      end

      context 'when set_echeckin_started call succeeds' do
        it 'calls set_echeckin_started and returns valid response' do
          VCR.use_cassette 'check_in/lorota/token/token_200' do
            post '/check_in/v2/sessions', **session_params
            expect(response).to have_http_status(:ok)
          end

          VCR.use_cassette('check_in/lorota/data/data_200', match_requests_on: [:host]) do
            VCR.use_cassette 'check_in/chip/set_echeckin_started/set_echeckin_started_200' do
              VCR.use_cassette 'check_in/chip/token/token_200' do
                get "/check_in/v2/patient_check_ins/#{id}"
              end
            end
          end
          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)).to eq(resp)
        end
      end

      context 'when setECheckinStartedCalled set to true' do
        let(:resp_with_true_set_e_check_in) do
          resp['payload']['setECheckinStartedCalled'] = true
          resp
        end

        it 'returns valid response without calling set_echeckin_started' do
          VCR.use_cassette 'check_in/lorota/token/token_200' do
            post '/check_in/v2/sessions', **session_params
            expect(response).to have_http_status(:ok)
          end

          VCR.use_cassette('check_in/lorota/data/data_with_echeckin_started_200', match_requests_on: [:host]) do
            get "/check_in/v2/patient_check_ins/#{id}"
          end
          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)).to eq(resp_with_true_set_e_check_in)
        end
      end

      context 'when set_echeckin_started call fails' do
        let(:error_body) do
          {
            'errors' => [
              {
                'title' => 'Internal Server Error',
                'detail' => 'Internal Server Error',
                'code' => 'CHIP-API_500',
                'status' => '500'
              }
            ]
          }
        end
        let(:error_resp) { Faraday::Response.new(response_body: error_body, status: 500) }

        it 'returns error response' do
          VCR.use_cassette 'check_in/lorota/token/token_200' do
            post '/check_in/v2/sessions', **session_params
            expect(response).to have_http_status(:ok)
          end

          VCR.use_cassette('check_in/lorota/data/data_200', match_requests_on: [:host]) do
            VCR.use_cassette 'check_in/chip/set_echeckin_started/set_echeckin_started_500' do
              VCR.use_cassette 'check_in/chip/token/token_200' do
                get "/check_in/v2/patient_check_ins/#{id}"
              end
            end
          end
          expect(response.status).to eq(error_resp.status)
          expect(response.body).to eq(error_resp.body.to_json)
        end
      end
    end
  end

  describe 'POST `create`' do
    let(:post_params) { { patient_check_ins: { uuid: id, appointment_ien: '123-abc' } } }

    context 'when session is authorized' do
      let(:session_params) do
        {
          params: {
            session: {
              uuid: id,
              dob: '1950-01-27',
              last_name: 'Johnson'
            }
          }
        }
      end
      let(:response_body) { { 'data' => 'Checkin successful', 'status' => 200 } }
      let(:success_resp) { Faraday::Response.new(response_body:, status: 200) }

      it 'returns a successful response' do
        VCR.use_cassette 'check_in/lorota/token/token_200' do
          post '/check_in/v2/sessions', **session_params
          expect(response).to have_http_status(:ok)
        end

        VCR.use_cassette('check_in/lorota/data/data_200', match_requests_on: [:host]) do
          VCR.use_cassette 'check_in/chip/set_echeckin_started/set_echeckin_started_200' do
            VCR.use_cassette 'check_in/chip/token/token_200' do
              get "/check_in/v2/patient_check_ins/#{id}"
              expect(response).to have_http_status(:ok)
            end
          end
        end

        VCR.use_cassette('check_in/chip/check_in/check_in_200', match_requests_on: [:host]) do
          VCR.use_cassette 'check_in/chip/token/token_200' do
            post '/check_in/v2/patient_check_ins', params: post_params
          end
        end
        expect(response.status).to eq(success_resp.status)
        expect(response.body).to eq(success_resp.body.to_json)
      end
    end

    context 'when CHIP create_check_in returns 404' do
      let(:session_params) do
        {
          params: {
            session: {
              uuid: id,
              dob: '1960-03-12',
              last_name: 'Johnson'
            }
          }
        }
      end

      let(:error_body) do
        {
          'errors' => [
            {
              'title' => 'Not Found',
              'detail' => 'Not Found',
              'code' => 'CHIP-API_404',
              'status' => '404'
            }
          ]
        }
      end
      let(:error_resp) { Faraday::Response.new(response_body: error_body, status: 404) }

      it 'returns 404 error response' do
        VCR.use_cassette 'check_in/lorota/token/token_200' do
          post '/check_in/v2/sessions', **session_params
          expect(response).to have_http_status(:ok)
        end

        VCR.use_cassette('check_in/chip/check_in/check_in_404', match_requests_on: [:host]) do
          VCR.use_cassette 'check_in/chip/token/token_200' do
            post '/check_in/v2/patient_check_ins', params: post_params
          end
        end
        expect(response.status).to eq(error_resp.status)
        expect(response.body).to eq(error_resp.body.to_json)
      end
    end

    context 'when CHIP create_check_in throws exception with 500 status code' do
      let(:session_params) do
        {
          params: {
            session: {
              uuid: id,
              dob: '1960-03-12',
              last_name: 'Johnson'
            }
          }
        }
      end

      let(:error_body) do
        {
          'errors' => [
            {
              'title' => 'Internal Server Error',
              'detail' => 'Internal Server Error',
              'code' => 'CHIP-API_500',
              'status' => '500'
            }
          ]
        }
      end
      let(:error_resp) { Faraday::Response.new(response_body: error_body, status: 500) }

      it 'returns 500 error response' do
        VCR.use_cassette 'check_in/lorota/token/token_200' do
          post '/check_in/v2/sessions', **session_params
          expect(response).to have_http_status(:ok)
        end

        VCR.use_cassette('check_in/chip/check_in/check_in_500', match_requests_on: [:host]) do
          VCR.use_cassette 'check_in/chip/token/token_200' do
            post '/check_in/v2/patient_check_ins', params: post_params
          end
        end
        expect(response.status).to eq(error_resp.status)
        expect(response.body).to eq(error_resp.body.to_json)
      end
    end

    context 'when session is not authorized' do
      let(:response_body) { { 'permissions' => 'read.none', 'status' => 'success', 'uuid' => id } }
      let(:unauth_response) { Faraday::Response.new(response_body:, status: 200) }

      it 'returns unauthorized response' do
        post '/check_in/v2/patient_check_ins', params: post_params

        expect(response.body).to eq(unauth_response.body.to_json)
        expect(response.status).to eq(unauth_response.status)
      end
    end
  end
end
