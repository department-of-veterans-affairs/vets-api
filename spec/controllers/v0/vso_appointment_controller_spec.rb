# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::VsoAppointmentsController, type: :controller do
  context 'before login' do
    it 'should reject a post' do
      post :create, 'beep': 'boop'
      expect(response).to have_http_status(:unauthorized)
    end
  end

  context 'after auth' do
    let(:token) { 'abracadabra' }
    let(:auth_header) { ActionController::HttpAuthentication::Token.encode_credentials(token) }
    let(:test_user) { FactoryBot.build(:user) }

    before(:each) do
      Session.create(uuid: test_user.uuid, token: token)
      User.create(test_user)
      request.env['HTTP_AUTHORIZATION'] = auth_header
    end

    it 'should reject an incomplete post' do
      post :create, "beep": 'boop'
      expect(response).to have_http_status(:bad_request)
    end

    it 'should balk at a bunch of garbage values' do
      payload = {}
      VsoAppointment.attribute_set.each { |attr| payload[attr.name.to_s] = 'beep' }

      post :create, payload
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

        post :create, payload
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
