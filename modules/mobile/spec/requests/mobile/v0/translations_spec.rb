# frozen_string_literal: true

require_relative '../../../support/helpers/rails_helper'

RSpec.describe 'Mobile::V0::Translations', type: :request do
  describe 'GET /mobile/v0/translations/download' do
    let(:file_hex) do
      file = Rails.root.join('modules', 'mobile', 'app', 'assets', 'translations', 'en', 'common.json')
      Digest::MD5.file(file).hexdigest
    end

    before do
      sis_user
    end

    context 'when no current_version is provided', :skip_json_api_validation do
      it 'returns file' do
        get '/mobile/v0/translations/download', headers: sis_headers

        expect(response).to have_http_status(:ok)
        expect(response.headers['Content-Version']).to eq(file_hex)
        expect(response.headers['Content-Disposition'])
          .to eq("attachment; filename=\"common.json\"; filename*=UTF-8''common.json")
        expect(response.headers['Content-Transfer-Encoding']).to eq('binary')
        expect(response.headers['Content-Type']).to eq('application/json')
        expect(response.body).to be_a(String)
      end
    end

    context 'when current_version does not match the file\'s current version', :skip_json_api_validation do
      it 'returns file' do
        get '/mobile/v0/translations/download', headers: sis_headers,
                                                params: { current_version: 'itcouldbeanything' }

        expect(response).to have_http_status(:ok)
        expect(response.headers['Content-Version']).to eq(file_hex)
        expect(response.headers['Content-Disposition'])
          .to eq("attachment; filename=\"common.json\"; filename*=UTF-8''common.json")
        expect(response.headers['Content-Transfer-Encoding']).to eq('binary')
        expect(response.headers['Content-Type']).to eq('application/json')
        expect(response.body).to be_a(String)
      end
    end

    context 'when current_version matches the file\'s current version' do
      it 'returns no content' do
        get '/mobile/v0/translations/download', headers: sis_headers, params: { current_version: file_hex }

        expect(response).to have_http_status(:no_content)
        expect(response.body).to be_empty
      end
    end
  end
end
