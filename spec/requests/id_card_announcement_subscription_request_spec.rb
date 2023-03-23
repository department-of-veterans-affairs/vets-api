# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Requesting ID Card Announcement Subscription' do
  def email
    params[:id_card_announcement_subscription][:email]
  end

  describe 'with valid params' do
    let(:params) do
      {
        id_card_announcement_subscription: {
          email: 'test@example.com'
        }
      }
    end

    it 'creates the subscription' do
      post('/v0/id_card/announcement_subscription', params:)
      expect(response).to have_http_status(:accepted)
      expect(IdCardAnnouncementSubscription.find_by(email:)).to be_present
    end
  end

  describe 'with a non-unique address' do
    let(:params) do
      {
        id_card_announcement_subscription: {
          email: 'test@example.com'
        }
      }
    end

    before do
      IdCardAnnouncementSubscription.create(email:)
    end

    it 'creates the subscription' do
      post('/v0/id_card/announcement_subscription', params:)
      expect(response).to have_http_status(:accepted)
    end
  end

  describe 'with invalid params' do
    let(:params) do
      {
        id_card_announcement_subscription: {
          email: 'test'
        }
      }
    end

    it 'responds with unprocessable entity and validation error' do
      post('/v0/id_card/announcement_subscription', params:)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to be_a(String)

      json = JSON.parse(response.body)
      expect(json['errors'][0]['title']).to eq('Email is invalid')
    end
  end

  describe 'with missing params' do
    it 'responds with bad request' do
      post '/v0/id_card/announcement_subscription'
      expect(response).to have_http_status(:bad_request)
    end
  end
end
