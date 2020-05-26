# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::Profile::VaFileNumbersController, type: :controller do
  let(:user) { create(:evss_user) }

  before do
    sign_in_as(user)
  end

  describe '#show' do
    context 'with a valid bgs response' do
      it 'returns a va file number for the logged-in user' do
        VCR.use_cassette('bgs/person_web_service/find_person_by_ptcpnt_id') do
          get(:show)
          expect(response.code).to eq('200')
          expect(response).to have_http_status(:ok)

          expect(JSON.parse(response.body)['data']['type']).to eq('va_file_number')
        end
      end
    end
  end
end