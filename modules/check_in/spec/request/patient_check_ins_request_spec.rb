# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PatientCheckIns', type: :request do
  describe 'GET `show`' do
    before do
      allow(Flipper).to receive(:enabled?).with('check_in_experience_enabled', anything).and_return(true)
    end

    it 'returns an empty response' do
      get '/check_in/v0/patient_check_ins/123aBc?cookie_id=23496jgsdf'

      expect(JSON.parse(response.body)).to eq({ 'data' => {} })
    end
  end

  describe 'POST `create`' do
    before do
      allow(Flipper).to receive(:enabled?).with('check_in_experience_enabled', anything).and_return(true)
    end

    it 'returns a default json payload' do
      post '/check_in/v0/patient_check_ins', params: { patient_check_ins: { id: '123aBc' }, cookie_id: '23496jgsdf' }

      expect(JSON.parse(response.body)).to eq({ 'data' => { 'status' => 'checked-in' } })
    end
  end
end
