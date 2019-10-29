# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'systems', type: :request do
  include SchemaMatchers

  let(:rsa_private) { OpenSSL::PKey::RSA.generate 4096 }

  before do
    sign_in_as(user)
    allow_any_instance_of(VAOS::JWT).to receive(:rsa_private).and_return(rsa_private)
  end

  context 'with a loa1 user' do
    let(:user) { FactoryBot.create(:user, :loa1, ssn: '111223333') }

    it 'returns a forbidden error' do
      get '/services/vaos/v0/systems'
      expect(response).to have_http_status(:forbidden)
    end
  end

  context 'with a loa3 user' do
    let(:user) { FactoryBot.create(:user, :loa3, ssn: '111223333') }

    context 'with a valid GET systems response' do
      it 'returns a 200 with the correct schema' do
        VCR.use_cassette('vaos/systems/get_systems', match_requests_on: %i[host path method]) do
          get '/services/vaos/v0/systems'
          expect(response).to have_http_status(:ok)
          expect(response.body).to be_a(String)
          expect(response).to match_response_schema('vaos/systems')
        end
      end
    end
  end
end
