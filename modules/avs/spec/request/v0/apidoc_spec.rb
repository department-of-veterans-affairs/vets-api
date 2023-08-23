# frozen_string_literal: true

require 'rails_helper'
require 'apivore'

RSpec.describe 'Avs API Documentation', type: :request do
  include AuthenticatedSessionHelper

  before(:all) do
    get '/avs/v0/apidocs.json'
  end

  context 'json validation' do
    it 'has valid json' do
      get '/avs/v0/apidocs.json'
      json = response.body
      expect(JSON.parse(json).to_yaml).to be_a(String)
    end
  end

  context 'API Documentation', type: %i[apivore request] do
    subject(:apivore) do
      Apivore::SwaggerChecker.instance_for('/avs/v0/apidocs.json')
    end

    let(:user01) { build(:user, :loa3, { email: 'vets.gov.user+1@gmail.com' }) }
    let(:params) do
      {
        '_headers' => {
          'Cookie' => sign_in(user01, nil, true),
          'accept' => 'application/json',
          'content-type' => 'application/json'
        }
      }
    end

    context 'avs/v0/avs/search' do
      describe 'Invalid parameters' do
        it 'Returns 400 when parameters are invalid' do
          expect(subject).to validate(
            :get,
            '/avs/v0/avs/search',
            400,
            params.merge('_query_string' =>
              {
                'appointmentIen' => 'abc',
                'stationNo' => 'cba'
              }.to_query)
          )
        end
      end

      describe 'Successful search' do
        it 'supports searching for an AVS' do
          VCR.use_cassette('/avs/search/9876543') do
            expect(subject).to validate(
              :get,
              '/avs/v0/avs/search',
              200,
              params.merge('_query_string' =>
                {
                  'appointmentIen' => '9876543',
                  'stationNo' => '500'
                }.to_query)
            )
          end
        end
      end
    end

    context 'avs/v0/avs/{id}' do
      it 'supports retrieving an AVS' do
        VCR.use_cassette('avs/show/9A7AF40B2BC2471EA116891839113252') do
          expect(subject).to validate(
            :get,
            '/avs/v0/avs/{id}',
            200,
            params.merge('id' => '9A7AF40B2BC2471EA116891839113252')
          )
        end
      end
    end
  end
end
