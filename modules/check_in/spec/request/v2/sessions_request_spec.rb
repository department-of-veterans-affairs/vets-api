# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V2::SessionsController', type: :request do
  let(:id) { 'd602d9eb-9a31-484f-9637-13ab0b507e0d' }
  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }

  before do
    allow(Rails).to receive(:cache).and_return(memory_store)
    allow(Flipper).to receive(:enabled?)
      .with('check_in_experience_enabled').and_return(true)
    allow(Flipper).to receive(:enabled?).with('check_in_experience_mock_enabled').and_return(false)

    Rails.cache.clear
  end

  describe 'GET `show`' do
    context 'when invalid uuid' do
      let(:invalid_uuid) { 'invalid_uuid' }
      let(:resp) do
        {
          'error' => true,
          'message' => 'Invalid dob or last name!'
        }
      end

      it 'returns an error response' do
        get "/check_in/v2/sessions/#{invalid_uuid}"

        # Even though this is unauthorized, we want to return a 200 back.
        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)).to eq(resp)
      end
    end

    context 'when token not present in session cookie or cache' do
      let(:uuid) { Faker::Internet.uuid }
      let(:resp) do
        {
          'permissions' => 'read.none',
          'status' => 'success',
          'uuid' => uuid
        }
      end

      it 'returns read.none permissions' do
        get check_in.v2_session_path(uuid)

        # Even though this is unauthorized, we want to return a 200 back.
        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)).to eq(resp)
      end
    end

    context 'when token present in session created with DOB' do
      let(:uuid) { Faker::Internet.uuid }
      let(:key) { "check_in_lorota_v2_#{uuid}_read.full" }
      let(:resp) do
        {
          'permissions' => 'read.full',
          'status' => 'success',
          'uuid' => uuid
        }
      end
      let(:session_params) do
        {
          params: {
            session: {
              uuid:,
              dob: '1947-08-15',
              last_name: 'Johnson'
            }
          }
        }
      end

      before do
        VCR.use_cassette 'check_in/lorota/token/token_200' do
          post '/check_in/v2/sessions', **session_params
        end
      end

      it 'returns read.full permissions' do
        get "/check_in/v2/sessions/#{uuid}"

        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)).to eq(resp)
      end
    end

    context 'when precheckin' do
      let(:uuid) { Faker::Internet.uuid }
      let(:resp) do
        {
          'permissions' => 'read.none',
          'status' => 'success',
          'uuid' => uuid
        }
      end

      context 'refresh_precheckin returns 200' do
        it 'returns a valid unauthorized response' do
          VCR.use_cassette('check_in/chip/refresh_pre_check_in/refresh_pre_check_in_200', erb: { uuid: }) do
            VCR.use_cassette 'check_in/chip/token/token_200' do
              get "/check_in/v2/sessions/#{uuid}?checkInType=preCheckIn"

              expect(response.status).to eq(200)
              expect(JSON.parse(response.body)).to eq(resp)
            end
          end
        end
      end

      context 'refresh_precheckin returns 404' do
        let(:error_resp) do
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

        it 'throws a 404 error' do
          VCR.use_cassette('check_in/chip/refresh_pre_check_in/refresh_pre_check_in_404', erb: { uuid: }) do
            VCR.use_cassette 'check_in/chip/token/token_200' do
              get "/check_in/v2/sessions/#{uuid}?checkInType=preCheckIn"

              expect(response.status).to eq(404)
              expect(JSON.parse(response.body)).to eq(error_resp)
            end
          end
        end
      end

      context 'refresh_precheckin returns 500' do
        let(:error_resp) do
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

        it 'throws an error' do
          VCR.use_cassette('check_in/chip/refresh_pre_check_in/refresh_pre_check_in_500', erb: { uuid: }) do
            VCR.use_cassette 'check_in/chip/token/token_200' do
              get "/check_in/v2/sessions/#{uuid}?checkInType=preCheckIn"

              expect(response.status).to eq(500)
              expect(JSON.parse(response.body)).to eq(error_resp)
            end
          end
        end
      end
    end

    context 'when day of checkin' do
      let(:uuid) { Faker::Internet.uuid }

      before do
        expect_any_instance_of(::V2::Chip::Service).not_to receive(:refresh_precheckin)
      end

      it 'does not call refresh_precheckin' do
        get "/check_in/v2/sessions/#{uuid}"
      end
    end
  end

  describe 'POST `create`' do
    let(:uuid) { Faker::Internet.uuid }
    let(:resp) do
      {
        'permissions' => 'read.full',
        'status' => 'success',
        'uuid' => uuid
      }
    end
    let(:session_params) do
      {
        params: {
          session: {
            uuid:,
            last4: '5555',
            last_name: 'Johnson'
          }
        }
      }
    end
    let(:key) { "check_in_lorota_v2_#{uuid}_read.full" }
    let(:error_response_410) do
      { 'errors' => [{ 'title' => 'Data Gone', 'detail' => 'Retry Attempt Exceeded', 'code' => 'CIE-VETS-API_410',
                       'status' => '410' }] }
    end

    context 'when invalid params in session created using DOB' do
      let(:invalid_uuid) { 'invalid_uuid' }
      let(:resp) do
        {
          'error' => true,
          'message' => 'Invalid dob or last name!'
        }
      end
      let(:session_params) do
        {
          params: {
            session: {
              uuid:,
              dob: '19-7-8',
              last_name: ''
            }
          }
        }
      end

      it 'returns an error response' do
        post '/check_in/v2/sessions', **session_params

        expect(response.status).to eq(400)
        expect(JSON.parse(response.body)).to eq(resp)
      end
    end

    context 'when JWT token and Redis entries are present in session created using DOB' do
      let(:session_params) do
        {
          params: {
            session: {
              uuid:,
              dob: '1980-03-18',
              last_name: 'Johnson'
            }
          }
        }
      end

      it 'returns a success response' do
        allow_any_instance_of(CheckIn::V2::Session).to receive(:redis_session_prefix).and_return('check_in_lorota_v2')
        allow_any_instance_of(CheckIn::V2::Session).to receive(:jwt).and_return('jwt-123-1bc')

        Rails.cache.write(key, 'jwt-123-1bc', namespace: 'check-in-lorota-v2-cache')

        post '/check_in/v2/sessions', **session_params

        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)).to eq(resp)
      end
    end

    context 'when JWT token and Redis entries are absent in session created using DOB' do
      let(:session_params) do
        {
          params: {
            session: {
              uuid:,
              dob: '1980-03-18',
              last_name: 'Johnson'
            }
          }
        }
      end

      before do
        expect_any_instance_of(::V2::Chip::Client).not_to receive(:set_precheckin_started).with(anything)
      end

      it 'returns a success response' do
        VCR.use_cassette 'check_in/lorota/token/token_200' do
          post '/check_in/v2/sessions', **session_params

          expect(response.status).to eq(200)
          expect(JSON.parse(response.body)).to eq(resp)
        end
      end
    end

    context 'when LoROTA returns a 401 for token' do
      let(:resp) do
        {
          'errors' => [
            {
              'title' => 'Authentication Error',
              'detail' => 'Authentication Error',
              'code' => 'LOROTA-API_401',
              'status' => '401'
            }
          ]
        }
      end

      context 'in session created using DOB' do
        let(:session_params_with_dob) do
          {
            params: {
              session: {
                uuid:,
                dob: '1980-03-18',
                last_name: 'Johnson'
              }
            }
          }
        end

        context 'for retry_attempt < max_auth_retry_limit' do
          let(:retry_count) { 1 }

          before do
            Rails.cache.write(
              "authentication_retry_limit_#{uuid}",
              retry_count,
              namespace: 'check-in-lorota-v2-cache',
              expires_in: 604_800
            )
          end

          it 'returns a 401 error' do
            VCR.use_cassette 'check_in/lorota/token/token_401' do
              post '/check_in/v2/sessions', **session_params_with_dob

              expect(response.status).to eq(401)
              expect(JSON.parse(response.body)).to eq(resp)
            end
          end

          it 'increments retry_attempt count in redis' do
            VCR.use_cassette 'check_in/lorota/token/token_401' do
              post '/check_in/v2/sessions', **session_params_with_dob

              redis_retry_attempt = Rails.cache.read(
                "authentication_retry_limit_#{uuid}",
                namespace: 'check-in-lorota-v2-cache'
              )
              expect(redis_retry_attempt).to eq(retry_count + 1)
            end
          end
        end

        context 'for retry_attempt > max_auth_retry_limit' do
          let(:retry_count) { 4 }

          before do
            Rails.cache.write(
              "authentication_retry_limit_#{uuid}",
              retry_count,
              namespace: 'check-in-lorota-v2-cache',
              expires_in: 604_800
            )
          end

          it 'returns a 410 error' do
            VCR.use_cassette('check_in/chip/delete/delete_from_lorota_200', erb: { uuid: }) do
              VCR.use_cassette 'check_in/chip/token/token_200' do
                VCR.use_cassette 'check_in/lorota/token/token_401' do
                  post '/check_in/v2/sessions', **session_params_with_dob

                  expect(response.status).to eq(410)
                  expect(JSON.parse(response.body)).to eq(error_response_410)
                end
              end
            end
          end

          it 'returns a 410 unique error message for any token endpoint failure message' do
            VCR.use_cassette('check_in/chip/delete/delete_from_lorota_200', erb: { uuid: }) do
              VCR.use_cassette 'check_in/chip/token/token_200' do
                VCR.use_cassette 'check_in/lorota/token/token_dob_mismatch_401' do
                  post '/check_in/v2/sessions', **session_params_with_dob

                  expect(response.status).to eq(410)
                  expect(JSON.parse(response.body)).to eq(error_response_410)
                end
              end
            end
          end

          it 'still returns a 410 error message if delete endpoint fails' do
            VCR.use_cassette('check_in/chip/delete/delete_from_lorota_500', erb: { uuid: }) do
              VCR.use_cassette 'check_in/chip/token/token_200' do
                VCR.use_cassette 'check_in/lorota/token/token_dob_mismatch_401' do
                  post '/check_in/v2/sessions', **session_params_with_dob

                  expect(response.status).to eq(410)
                  expect(JSON.parse(response.body)).to eq(error_response_410)
                end
              end
            end
          end
        end
      end
    end

    context 'when pre_checkin in session created using DOB' do
      let(:session_params) do
        {
          params: {
            session: {
              uuid:,
              dob: '1940-06-19',
              last_name: 'Johnson',
              check_in_type: 'preCheckIn'
            }
          }
        }
      end

      context 'when CHIP sets precheckin started status successfully' do
        it 'returns a success response' do
          VCR.use_cassette('check_in/chip/set_precheckin_started/set_precheckin_started_200',
                           erb: { uuid: }) do
            VCR.use_cassette 'check_in/chip/token/token_200' do
              VCR.use_cassette 'check_in/lorota/token/token_200' do
                post '/check_in/v2/sessions', **session_params

                expect(response.status).to eq(200)
                expect(JSON.parse(response.body)).to eq(resp)
              end
            end
          end
        end
      end

      context 'when CHIP returns 404 for precheckin started' do
        it 'returns a success response' do
          VCR.use_cassette('check_in/chip/set_precheckin_started/set_precheckin_started_404',
                           erb: { uuid: }) do
            VCR.use_cassette 'check_in/chip/token/token_200' do
              VCR.use_cassette 'check_in/lorota/token/token_200' do
                post '/check_in/v2/sessions', **session_params

                expect(response.status).to eq(200)
                expect(JSON.parse(response.body)).to eq(resp)
              end
            end
          end
        end
      end

      context 'when CHIP returns 500 error for precheckin started call' do
        it 'returns a success response' do
          VCR.use_cassette('check_in/chip/set_precheckin_started/set_precheckin_started_500',
                           erb: { uuid: }) do
            VCR.use_cassette 'check_in/chip/token/token_200' do
              VCR.use_cassette 'check_in/lorota/token/token_200' do
                post '/check_in/v2/sessions', **session_params

                expect(response.status).to eq(200)
                expect(JSON.parse(response.body)).to eq(resp)
              end
            end
          end
        end
      end
    end
  end
end
