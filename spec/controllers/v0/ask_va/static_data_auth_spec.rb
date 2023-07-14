# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'StaticDataAuth', type: :request do
  let(:user) { create(:user, :loa3, ssn: '111223333') }

  describe 'GET /v0/ask_va/static_data_auth' do
    it 'returns the same authenticated data' do
      sign_in_as(user)
      get v0_ask_va_static_data_auth_path
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq({
                                                'Ruchi' => { 'data-info' => 'ruchi.shah@thoughtworks.com' },
                                                'Eddie' => { 'data-info' => 'eddie.otero@oddball.io' },
                                                'Jacob' => { 'data-info' => 'jacob@docme360.com' },
                                                'Joe' => { 'data-info' => 'joe.hall@thoughtworks.com' },
                                                'Khoa' => { 'data-info' => 'khoa.nguyen@oddball.io' }
                                              })
    end
  end
end
