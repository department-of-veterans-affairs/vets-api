# frozen_string_literal: true

require_relative '../../../../support/helpers/rails_helper'
RSpec.describe 'Mobile::V0::User::Demographics', type: :request do
  describe 'logingov user' do
    let!(:user) do
      sis_user(
        icn: '1008596379V859838',
        idme_uuid: nil,
        logingov_uuid: 'b2fab2b5-6af0-45e1-a9e2-394347af91ef',
        authn_context: 'dslogon_loa3'
      )
    end

    describe 'GET /mobile/v0/user/demographics' do
      context 'returns as expected' do
        before do
          VCR.use_cassette('mobile/demographics/logingov') do
            get('/mobile/v0/user/demographics', headers: sis_headers(camelize: false))
          end
        end

        it 'returns gender identity and preferred name' do
          expect(response.parsed_body).to eq({ 'data' =>
                                                { 'id' => user.uuid,
                                                  'type' => 'demographics',
                                                  'attributes' =>
                                                   { 'gender_identity' => nil, 'preferred_name' => 'SAM' } } })
        end
      end
    end
  end

  describe 'idme user' do
    let!(:user) do
      sis_user(icn: '1008596379V859838', idme_uuid: 'b2fab2b5-6af0-45e1-a9e2-394347af91ef')
    end

    describe 'GET /mobile/v0/user/demographics' do
      context 'returns as expected' do
        before do
          VCR.use_cassette('mobile/va_profile/demographics/demographics') do
            get('/mobile/v0/user/demographics', headers: sis_headers(camelize: false))
          end
        end

        it 'returns gender identity and preferred name' do
          expect(response.parsed_body).to eq({ 'data' =>
                                                { 'id' => user.uuid,
                                                  'type' => 'demographics',
                                                  'attributes' =>
                                                   { 'gender_identity' => nil, 'preferred_name' => 'SAM' } } })
        end
      end

      context 'upstream service returns 503 error' do
        before do
          VCR.use_cassette('mobile/va_profile/demographics/demographics_error_503') do
            get('/mobile/v0/user/demographics', headers: sis_headers(camelize: false))
          end
        end

        it 'endpoint returns 502 error' do
          expect(response.parsed_body).to eq({ 'errors' =>
                                                [{ 'title' => 'Bad Gateway',
                                                   'detail' =>
                                                    'Received an an invalid response from the upstream server',
                                                   'code' => 'VET360_502',
                                                   'source' => 'VAProfile::Demographics::Service',
                                                   'status' => '502' }] })
        end
      end

      context 'upstream service returns 404 error' do
        before do
          VCR.use_cassette('mobile/va_profile/demographics/demographics_error_404') do
            get('/mobile/v0/user/demographics', headers: sis_headers(camelize: false))
          end
        end

        it 'endpoint returns as 404 error' do
          expect(response.parsed_body).to eq({ 'errors' =>
                                                [{ 'title' => 'Record not found',
                                                   'detail' => "The record identified by #{user.uuid}" \
                                                               ' could not be found',
                                                   'code' => '404',
                                                   'status' => '404' }] })
        end
      end

      context 'upstream service returns 400 error' do
        before do
          VCR.use_cassette('mobile/va_profile/demographics/demographics_error_400') do
            get('/mobile/v0/user/demographics', headers: sis_headers(camelize: false))
          end
        end

        it 'endpoint returns as 400 error' do
          expect(response.parsed_body).to eq({ 'errors' =>
                                                [{ 'title' => 'Bad request',
                                                   'detail' => 'Bad request',
                                                   'code' => '400',
                                                   'status' => '400' }] })
        end
      end
    end
  end

  describe 'unauthorized user' do
    let!(:user) { sis_user(idme_uuid: nil, logingov_uuid: nil) }

    context 'returns as expected' do
      before do
        get('/mobile/v0/user/demographics', headers: sis_headers(camelize: false))
      end

      it 'returns forbidden error' do
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
