# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V2::Demographics', type: :request do
  let(:id) { '5bcd636c-d4d3-4349-9058-03b2f6b38ced' }
  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }

  before do
    allow(Rails).to receive(:cache).and_return(memory_store)
    allow(Flipper).to receive(:enabled?).with('check_in_experience_enabled').and_return(true)
    allow(Flipper).to receive(:enabled?).with('check_in_experience_enabled', anything).and_return(true)
    allow(Flipper).to receive(:enabled?).with('check_in_experience_mock_enabled').and_return(false)

    Rails.cache.clear
  end

  describe 'PATCH `update` with DOB in the session' do
    let(:session_params_with_dob) do
      {
        params: {
          session: {
            uuid: id,
            dob: '1970-02-23',
            last_name: 'Johnson'
          }
        }
      }
    end

    context 'when JWT token and Redis entries are absent' do
      it 'returns unauthorized status' do
        patch "/check_in/v2/demographics/#{id}"

        expect(response.status).to eq(401)
      end
    end

    context 'when called without demographic_confirmations in authorized session' do
      let(:invalid_params) do
        {
          demographics: {
            mailing_address: {
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
          }
        }
      end

      it 'returns bad request' do
        VCR.use_cassette 'check_in/lorota/token/token_200' do
          post '/check_in/v2/sessions', **session_params_with_dob
          expect(response.status).to eq(200)
        end

        VCR.use_cassette('check_in/lorota/data/data_200', match_requests_on: [:host]) do
          get "/check_in/v2/patient_check_ins/#{id}"
          expect(response.status).to eq(200)
        end

        VCR.use_cassette('check_in/chip/token/token_200') do
          patch "/check_in/v2/demographics/#{id}", params: invalid_params
        end
        expect(response.status).to eq(400)
      end
    end

    context 'when CHIP confirm_demographics throws 504 exception' do
      let(:params) do
        {
          demographics: {
            demographic_confirmations: {
              'demographics_up_to_date' => true,
              'next_of_kin_up_to_date' => true,
              'emergency_contact_up_to_date' => false
            }
          }
        }
      end

      let(:operation_failed) do
        {
          'title' => 'Operation failed',
          'detail' => 'Operation failed',
          'code' => 'VA900',
          'status' => '400'
        }
      end
      let(:error_resp) { { 'errors' => [operation_failed] } }

      it 'returns error response' do
        VCR.use_cassette 'check_in/lorota/token/token_200' do
          post '/check_in/v2/sessions', **session_params_with_dob
          expect(response.status).to eq(200)
        end

        VCR.use_cassette('check_in/lorota/data/data_200', match_requests_on: [:host]) do
          get "/check_in/v2/patient_check_ins/#{id}"
          expect(response.status).to eq(200)
        end

        VCR.use_cassette('check_in/chip/confirm_demographics/confirm_demographics_504', match_requests_on: [:host]) do
          VCR.use_cassette('check_in/chip/token/token_200') do
            patch "/check_in/v2/demographics/#{id}", params: params
          end
        end
        expect(response.status).to eq(400)
        expect(JSON.parse(response.body)).to eq(error_resp)
      end
    end

    context 'when called with demographic_confirmations in authorized session' do
      let(:params) do
        {
          demographics: {
            demographic_confirmations: {
              'demographics_up_to_date' => true,
              'next_of_kin_up_to_date' => true,
              'emergency_contact_up_to_date' => false
            }
          }
        }
      end
      let(:demographic_attributes) do
        {
          'id' => 5,
          'patientDfn' => 418,
          'demographicsNeedsUpdate' => false,
          'demographicsConfirmedAt' => '2022-01-22T12:00:00.000-05:00',
          'nextOfKinNeedsUpdate' => false,
          'nextOfKinConfirmedAt' => '2022-02-03T12:00:00.000-05:00',
          'emergencyContactNeedsUpdate' => true,
          'emergencyContactConfirmedAt' => '2022-01-27T12:00:00.000-05:00',
          'insuranceVerificationNeeded' => nil
        }
      end

      let(:resp) do
        {
          'data' => {
            'attributes' => demographic_attributes,
            'id' => 418
          }
        }
      end

      let(:faraday_response) { Faraday::Response.new(body: resp, status: 200) }
      let(:hsh) { { 'data' => faraday_response.body, 'status' => faraday_response.status } }

      it 'returns valid response' do
        VCR.use_cassette 'check_in/lorota/token/token_200' do
          post '/check_in/v2/sessions', **session_params_with_dob
          expect(response.status).to eq(200)
        end

        VCR.use_cassette('check_in/lorota/data/data_200', match_requests_on: [:host]) do
          get "/check_in/v2/patient_check_ins/#{id}"
          expect(response.status).to eq(200)
        end

        VCR.use_cassette('check_in/chip/confirm_demographics/confirm_demographics_200', match_requests_on: [:host]) do
          VCR.use_cassette('check_in/chip/token/token_200') do
            patch "/check_in/v2/demographics/#{id}", params: params
          end
        end
        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)).to eq(hsh)
      end
    end
  end
end
