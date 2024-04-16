# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::AverageDaysForClaimCompletionController, type: :controller do
  context 'when querying with nothing in db' do
    it 'returns -1 for value' do
      get :index
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['average_days']).to eq(-1.0)
    end
  end

  context 'when querying with record in db' do
    before do
      AverageDaysForClaimCompletion.create(average_days: 100)
    end

    it 'returns the value' do
      get :index
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['average_days']).to eq(100.0)
    end
  end

  context 'when querying with multiple records in db' do
    before do
      AverageDaysForClaimCompletion.create(average_days: 100)
      AverageDaysForClaimCompletion.create(average_days: 200)
      AverageDaysForClaimCompletion.create(average_days: 300)
    end

    it 'returns the most recently inserted value' do
      get :index
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['average_days']).to eq(300.0)
    end
  end
end
