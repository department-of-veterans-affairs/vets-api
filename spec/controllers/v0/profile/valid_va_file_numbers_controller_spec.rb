# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::Profile::ValidVAFileNumbersController, type: :controller do
  let(:user) { create(:evss_user) }

  describe '#show' do
    context 'with a valid bgs response' do
      it 'returns true if a logged-in user has a valid va file number' do
        VCR.use_cassette('bgs/person_web_service/find_person_by_participant_id') do
          sign_in_as(user)
          get(:show)

          expect(response).to have_http_status(:ok)
          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)['data']['attributes']['valid_va_file_number']).to be(true)
        end
      end
    end

    context 'with a user that does not have a valid va_file_number' do
      it 'returns null' do
        VCR.use_cassette('bgs/person_web_service/find_person_by_participant_id_no_result') do
          allow_any_instance_of(User).to receive(:participant_id).and_return('11111111111')
          sign_in_as(user)
          get(:show)
          expect(response).to have_http_status(:ok)
          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)['data']['attributes']['valid_va_file_number']).to be(false)
        end
      end
    end
  end
end
