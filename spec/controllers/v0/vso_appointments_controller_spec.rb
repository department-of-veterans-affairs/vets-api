# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::VSOAppointmentsController, type: :controller do
  context 'before login' do
    it 'rejects a post' do
      post :create, params: { 'beep': 'boop' }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  context 'after auth' do
    let(:user) { build(:user) }

    before do
      sign_in_as(user)
    end

    it 'rejects an incomplete post' do
      post :create, params: { "beep": 'boop' }
      expect(response).to have_http_status(:bad_request)
    end

    it 'balks at a bunch of garbage values' do
      payload = {}
      VSOAppointment.attribute_set.each { |attr| payload[attr.name.to_s] = 'beep' }
      %w[claimant_full_name veteran_full_name claimant_address].each do |attr|
        payload.delete(attr)
      end

      post :create, params: payload
      expect(response).to have_http_status(:bad_request)
    end

    it 'accepts a basic example' do
      VCR.use_cassette('vso_appointments/upload') do
        # fill in everything with junk by default
        payload = {}
        VSOAppointment.attribute_set.each { |attr| payload[attr.name.to_s] = 'beep' }

        # This will actually accept camel case, but /shrug
        payload = payload.merge(
          "veteran_full_name": {
            "first": 'Graham',
            "last": 'Testuser'
          },
          "claimant_full_name": {
            "first": 'the artist formely known as claimant'
          },
          "claimant_address": {
            "street": '123 Fake St'
          },
          "appointment_date": '2018-04-09'
        )

        post :create, params: payload
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
