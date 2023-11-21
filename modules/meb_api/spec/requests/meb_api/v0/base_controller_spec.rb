# frozen_string_literal: true

require 'rails_helper'
RSpec.describe MebApi::V0::BaseController, type: :request do
  let(:user_details_loa3) do
    {
      first_name: 'Lara',
      last_name: 'Stehr',
      middle_name: '',
      ssn: '777097308'
    }
  end
  let(:user_details_loa1) do
    {
      first_name: 'Lara',
      last_name: 'Stehr',
      middle_name: '',
      ssn: nil
    }
  end
  let(:user_loa1) { build(:user, :loa1, user_details_loa1) }
  let(:user_loa3) { build(:user, :loa3, user_details_loa3) }
  let(:headers) { { 'Content-Type' => 'application/json', 'Accept' => 'application/json' } }
  let(:faraday_response) { double('faraday_connection') }

  before do
    allow(faraday_response).to receive(:env)
  end

  describe 'GET /meb_api/v0/forms_claimant_info' do
    context 'when user has an ICN, SSN, and is LOA3' do
      before do
        sign_in_as(user_loa3)
      end

      it 'grants access' do
        VCR.use_cassette('dgi/forms/forms_claimant_info_loa3') do
          get '/meb_api/v0/forms_claimant_info'
          expect(response).to have_http_status(:ok)
        end
      end
    end

    context 'when user does not have ICN' do
      before do
        user_loa1 = build(:user, :loa1, icn: nil)
        sign_in_as(user_loa1)
      end

      it 'denies access' do
        get '/meb_api/v0/forms_claimant_info'
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when user does not have SSN' do
      before do
        user_loa1 = build(:user, :loa1, ssn: nil)
        sign_in_as(user_loa1)
      end

      it 'denies access' do
        get '/meb_api/v0/forms_claimant_info'
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when user is not LOA3' do
      before do
        sign_in_as(user_loa1)
      end

      it 'denies access' do
        get '/meb_api/v0/forms_claimant_info'
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'GET /meb_api/v0/claimant_info' do
    context 'when user has an ICN, SSN, and is LOA3' do
      before do
        sign_in_as(user_loa3)
      end

      it 'grants access' do
        VCR.use_cassette('dgi/claimant_info_loa3') do
          get '/meb_api/v0/claimant_info'
          expect(response).to have_http_status(:ok)
        end
      end
    end

    context 'when user does not have ICN' do
      before do
        user_loa1 = build(:user, :loa1, icn: nil)
        sign_in_as(user_loa1)
      end

      it 'denies access' do
        get '/meb_api/v0/claimant_info'
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when user does not have SSN' do
      before do
        user_loa1 = build(:user, :loa1, ssn: nil)
        sign_in_as(user_loa1)
      end

      it 'denies access' do
        get '/meb_api/v0/claimant_info'
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when user is not LOA3' do
      before do
        sign_in_as(user_loa1)
      end

      it 'denies access' do
        get '/meb_api/v0/claimant_info'
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
