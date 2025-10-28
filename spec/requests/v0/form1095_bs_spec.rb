# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V0::Form1095Bs', type: :request do
  subject { create(:form1095_b, tax_year: 2021) }

  let(:old_user) { build(:user, :loa3, icn: subject.veteran_icn) }
  let(:user) { build(:user, :loa3, icn: '1012667145V762142') }
  let(:invalid_user) { build(:user, :loa1, icn: subject.veteran_icn) }

  describe 'GET /download_pdf for valid user' do
    context 'when Flipper feature is disabled' do
      before do
        sign_in_as(old_user)
        allow(Flipper).to receive(:enabled?).with(:fetch_1095b_from_enrollment_system, any_args).and_return(false)
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

    context 'when Flipper feature is enabled' do
      before do
        sign_in_as(user)
        allow(Flipper).to receive(:enabled?).with(:fetch_1095b_from_enrollment_system, any_args).and_return(true)
      end

      it 'returns http success' do
        VCR.use_cassette('veteran_enrollment_system/form1095_b/get_form_success',
                         { match_requests_on: %i[method uri] }) do
          get '/v0/form1095_bs/download_pdf/2024'
          expect(response).to have_http_status(:success)
        end
      end

      it 'returns a PDF form' do
        VCR.use_cassette('veteran_enrollment_system/form1095_b/get_form_success',
                         { match_requests_on: %i[method uri] }) do
          get '/v0/form1095_bs/download_pdf/2024'
          expect(response.content_type).to eq('application/pdf')
        end
      end

      # disabled pending work on https://github.com/department-of-veterans-affairs/va-iir/issues/2133
      xit 'throws 404 when form not found' do
        VCR.use_cassette('veteran_enrollment_system/form1095_b/get_form_not_found',
                         { match_requests_on: %i[method uri] }) do
          get '/v0/form1095_bs/download_pdf/2024'
          expect(response).to have_http_status(:not_found)
        end
      end

      # disabled pending work on https://github.com/department-of-veterans-affairs/va-iir/issues/2133
      xit 'throws 422 when no template exists for requested year' do
        create(:form1095_b, tax_year: 2018)
        get '/v0/form1095_bs/download_pdf/2018'
        expect(response).to have_http_status(:unprocessable_entity)
      end
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
    context 'when Flipper feature is disabled' do
      before do
        sign_in_as(old_user)
        allow(Flipper).to receive(:enabled?).with(:fetch_1095b_from_enrollment_system, any_args).and_return(false)
      end

      it 'returns http success' do
        get '/v0/form1095_bs/download_txt/2021'
        expect(response).to have_http_status(:success)
      end

      it 'returns a txt form' do
        get '/v0/form1095_bs/download_txt/2021'
        expect(response.content_type).to eq('text/plain')
      end

      xit 'throws 404 when form not found' do
        get '/v0/form1095_bs/download_txt/2018'
        expect(response).to have_http_status(:not_found)
      end

      xit 'throws 422 when no template exists for requested year' do
        create(:form1095_b, tax_year: 2018)
        get '/v0/form1095_bs/download_txt/2018'
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'when Flipper feature is enabled' do
      before do
        sign_in_as(user)
        allow(Flipper).to receive(:enabled?).with(:fetch_1095b_from_enrollment_system, any_args).and_return(true)
      end

      it 'returns http success' do
        VCR.use_cassette('veteran_enrollment_system/form1095_b/get_form_success',
                         { match_requests_on: %i[method uri] }) do
                           get '/v0/form1095_bs/download_txt/2024'
                           expect(response).to have_http_status(:success)
                         end
      end

      it 'returns a txt form' do
        VCR.use_cassette('veteran_enrollment_system/form1095_b/get_form_success',
                         { match_requests_on: %i[method uri] }) do
                           get '/v0/form1095_bs/download_txt/2024'
                           expect(response.content_type).to eq('text/plain')
                         end
      end

      # disabled pending work on https://github.com/department-of-veterans-affairs/va-iir/issues/2133
      it 'throws 404 when form not found' do
        get '/v0/form1095_bs/download_txt/2018'
        expect(response).to have_http_status(:not_found)
      end

      # disabled pending work on https://github.com/department-of-veterans-affairs/va-iir/issues/2133
      it 'throws 422 when no template exists for requested year' do
        create(:form1095_b, tax_year: 2018)
        get '/v0/form1095_bs/download_txt/2018'
        expect(response).to have_http_status(:unprocessable_entity)
      end
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
      # allow endpoint increment in order to test user_has_no_1095b increment
      allow(StatsD).to receive(:increment).with('api.rack.request',
                                                { tags: ['controller:v0/form1095_bs', 'action:available_forms',
                                                         'source_app:not_provided', 'status:200'] })
    end

    it 'returns success with only the most recent tax year form data' do
      this_year = Date.current.year
      last_year_form = create(:form1095_b, tax_year: this_year - 1)
      create(:form1095_b, tax_year: this_year)
      create(:form1095_b, tax_year: this_year - 2)

      expect(StatsD).not_to receive(:increment).with('api.user_has_no_1095b')
      get '/v0/form1095_bs/available_forms'
      expect(response).to have_http_status(:success)
      expect(response.parsed_body.deep_symbolize_keys).to eq(
        { available_forms: [{ year: last_year_form.tax_year,
                              last_updated: last_year_form.updated_at.strftime('%Y-%m-%dT%H:%M:%S.%LZ') }] }
      )
    end

    it 'returns success with no available forms and increments statsd when user has no form data' do
      expect(StatsD).to receive(:increment).with('api.user_has_no_1095b')
      get '/v0/form1095_bs/available_forms'
      expect(response).to have_http_status(:success)
      expect(response.parsed_body.symbolize_keys).to eq(
        { available_forms: [] }
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
