# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V0::Form1095Bs', type: :request do
  subject { create(:form1095_b) }

  let(:user) { build(:user, :loa3, icn: subject.veteran_icn) }
  let(:invalid_user) { build(:user, :loa1, icn: subject.veteran_icn) }

  describe 'GET /download_pdf for valid user' do
    before do
      sign_in_as(user)
    end

    it 'returns http success' do
      get '/v0/form1095_bs/download_pdf/2021'
      expect(response).to have_http_status(:success)
    end

    it 'returns a PDF form' do
      get '/v0/form1095_bs/download_pdf/2021'
      expect(response.content_type).to eq('application/pdf')
    end

    it 'throws 404 when form not found' do
      get '/v0/form1095_bs/download_pdf/2018'
      expect(response).to have_http_status(:not_found)
    end

    it 'throws 422 when no template exists for requested year' do
      create(:form1095_b, tax_year: 2018)
      get '/v0/form1095_bs/download_pdf/2018'
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'GET /download_pdf for invalid user' do
    before do
      sign_in_as(invalid_user)
    end

    it 'returns http 403' do
      get '/v0/form1095_bs/download_pdf/2021'
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET /download_txt for valid user' do
    before do
      sign_in_as(user)
    end

    it 'returns http success' do
      get '/v0/form1095_bs/download_txt/2021'
      expect(response).to have_http_status(:success)
    end

    it 'returns a txt form' do
      get '/v0/form1095_bs/download_txt/2021'
      expect(response.content_type).to eq('text/plain')
    end

    it 'throws 404 when form not found' do
      get '/v0/form1095_bs/download_txt/2018'
      expect(response).to have_http_status(:not_found)
    end

    it 'throws 422 when no template exists for requested year' do
      create(:form1095_b, tax_year: 2018)
      get '/v0/form1095_bs/download_txt/2018'
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'GET /download_txt for invalid user' do
    before do
      sign_in_as(invalid_user)
    end

    it 'returns http 403' do
      get '/v0/form1095_bs/download_txt/2021'
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET /available_forms' do
    before do
      sign_in_as(user)
    end

    it 'returns success with only the most recent tax year form data' do
      this_year = Date.current.year
      last_year_form = create(:form1095_b, tax_year: this_year - 1)
      create(:form1095_b, tax_year: this_year)
      create(:form1095_b, tax_year: this_year - 2)
      get '/v0/form1095_bs/available_forms'
      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body)).to eq(
        { 'available_forms' => [{ 'year' => last_year_form.tax_year,
                                  'last_updated' => last_year_form.updated_at.strftime('%Y-%m-%dT%H:%M:%S.%LZ') }] }
      )
    end

    it 'returns success with no available forms when user has no form data' do
      get '/v0/form1095_bs/available_forms'
      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body)).to eq(
        { 'available_forms' => [] }
      )
    end
  end

  describe 'GET /available_forms for invalid user' do
    before do
      sign_in_as(invalid_user)
    end

    it 'returns http 403' do
      get '/v0/form1095_bs/available_forms'
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET /available_forms when not logged in' do
    it 'returns http 401' do
      get '/v0/form1095_bs/available_forms'
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
