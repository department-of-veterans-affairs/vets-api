# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/helpers/iam_session_helper'
require 'va_profile/demographics/service'

RSpec.describe 'demographics', type: :request do
  include SchemaMatchers

  describe 'logingov user' do
    let(:csd) { 'LGN' }

    before do
      iam_sign_in(FactoryBot.build(:iam_user, :logingov))
      allow_any_instance_of(IAMUser).to receive(:logingov_uuid).and_return('b2fab2b5-6af0-45e1-a9e2-394347af91ef')
    end

    describe 'GET /mobile/v0/user/demographics' do
      context 'returns as expected' do
        before do
          VCR.use_cassette('mobile/demographics/logingov') do
            get('/mobile/v0/user/demographics', headers: iam_headers_no_camel)
          end
        end

        it 'returns gender identity and preferred name' do
          expect(response.parsed_body).to eq({ 'data' =>
                                                { 'id' => '1008596379V859838',
                                                  'type' => 'demographics',
                                                  'attributes' =>
                                                   { 'gender_identity' => 'F', 'preferred_name' => 'SAM' } } })
        end
      end
    end
  end

  describe 'idme user' do
    let(:csd) { 'IDM' }

    before do
      iam_sign_in(FactoryBot.build(:iam_user))
      allow_any_instance_of(IAMUser).to receive(:idme_uuid).and_return('b2fab2b5-6af0-45e1-a9e2-394347af91ef')
    end

    describe 'GET /mobile/v0/user/demographics' do
      context 'returns as expected' do
        before do
          VCR.use_cassette('mobile/va_profile/demographics/demographics') do
            get('/mobile/v0/user/demographics', headers: iam_headers_no_camel)
          end
        end

        it 'returns gender identity and preferred name' do
          expect(response.parsed_body).to eq({ 'data' =>
                                                { 'id' => '1008596379V859838',
                                                  'type' => 'demographics',
                                                  'attributes' =>
                                                   { 'gender_identity' => 'F', 'preferred_name' => 'SAM' } } })
        end
      end

      context 'upstream service returns 503 error' do
        before do
          VCR.use_cassette('mobile/va_profile/demographics/demographics_error_503') do
            get('/mobile/v0/user/demographics', headers: iam_headers_no_camel)
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
            get('/mobile/v0/user/demographics', headers: iam_headers_no_camel)
          end
        end

        it 'endpoint returns as 404 error' do
          expect(response.parsed_body).to eq({ 'errors' =>
                                                [{ 'title' => 'Record not found',
                                                   'detail' => 'The record identified by 1008596379V859838' \
                                                               ' could not be found',
                                                   'code' => '404',
                                                   'status' => '404' }] })
        end
      end

      context 'upstream service returns 400 error' do
        before do
          VCR.use_cassette('mobile/va_profile/demographics/demographics_error_400') do
            get('/mobile/v0/user/demographics', headers: iam_headers_no_camel)
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
    before do
      iam_sign_in(FactoryBot.build(:iam_user, :no_multifactor))
    end

    context 'returns as expected' do
      before do
        get('/mobile/v0/user/demographics', headers: iam_headers_no_camel)
      end

      it 'returns forbidden error' do
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
