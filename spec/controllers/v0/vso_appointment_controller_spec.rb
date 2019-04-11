# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::VsoAppointmentsController, type: :controller do
  context 'before login' do
    it 'should reject a post' do
      post :create, params: { 'beep': 'boop' }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  context 'after auth' do
    let(:user) { build(:user) }

    before(:each) do
      sign_in_as(user)
    end

    it 'should reject an incomplete post' do
      post :create, params: { "beep": 'boop' }
      expect(response).to have_http_status(:bad_request)
    end

    it 'should balk at a bunch of garbage values' do
      payload = {}
      VsoAppointment.attribute_set.each { |attr| payload[attr.name.to_s] = 'beep' }
      %w[claimant_full_name veteran_full_name claimant_address].each do |attr|
        payload.delete(attr)
      end

      post :create, params: payload
      expect(response).to have_http_status(:bad_request)
    end

    it 'should accept a basic example' do
      VCR.use_cassette('vso_appointments/upload') do
        # fill in everything with junk by default
        payload = {}
        VsoAppointment.attribute_set.each { |attr| payload[attr.name.to_s] = 'beep' }

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
