# frozen_string_literal: true

require_relative '../../../support/helpers/rails_helper'

RSpec.describe 'Mobile::V0::Translations', :skip_json_api_validation, type: :request do
  describe 'GET /mobile/v0/translations' do
    let(:file_last_changed) { Rails.root.join('modules/mobile/app/assets/translations/en/common.json').mtime.to_i }

    before do
      sis_user
    end

    context 'when no timestamp is provided' do
      it 'returns file' do
        get '/mobile/v0/translations', headers: sis_headers

        expect(response).to have_http_status(:ok)
        expect(response.headers['Content-Disposition'])
          .to eq("attachment; filename=\"common.json\"; filename*=UTF-8''common.json")
        expect(response.headers['Content-Transfer-Encoding']).to eq('binary')
        expect(response.headers['Content-Type']).to eq('application/json')
        expect(response.body).to be_a(String)
      end
    end

    context 'when timestamp is before when the translation file was last changed' do
      it 'returns file' do
        get '/mobile/v0/translations', headers: sis_headers, params: { last_downloaded: file_last_changed - 10 }

        expect(response).to have_http_status(:ok)
        expect(response.headers['Content-Disposition'])
          .to eq("attachment; filename=\"common.json\"; filename*=UTF-8''common.json")
        expect(response.headers['Content-Transfer-Encoding']).to eq('binary')
        expect(response.headers['Content-Type']).to eq('application/json')
        expect(response.body).to be_a(String)
      end
    end

    context 'when timestamp is equal to or after when the translation file was last changed' do
      it 'sends ok' do
        get '/mobile/v0/translations', headers: sis_headers, params: { last_downloaded: file_last_changed }

        expect(response).to have_http_status(:ok)
        expect(response.body).to eq(' ')
      end
    end
  end
end