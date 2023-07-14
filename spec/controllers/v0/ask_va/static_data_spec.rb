# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'StaticData', type: :request do
  describe 'GET /v0/ask_va/static_data' do
    it 'returns the same data' do
      get v0_ask_va_static_data_path
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq({
                                                'Emily' => { 'data-info' => 'emily@oddball.io' },
                                                'Eddie' => { 'data-info' => 'eddie.otero@oddball.io' },
                                                'Jacob' => { 'data-info' => 'jacob@docme360.com' },
                                                'Joe' => { 'data-info' => 'joe.hall@thoughtworks.com' },
                                                'Khoa' => { 'data-info' => 'khoa.nguyen@oddball.io' }
                                              })
    end
  end
end
