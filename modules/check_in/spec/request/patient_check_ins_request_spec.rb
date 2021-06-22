# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PatientCheckIns', type: :request do
  describe 'GET `show`' do
    it 'returns an empty response' do
      get '/check_in/v0/patient_check_ins/123aBc'

      expect(JSON.parse(response.body)).to eq({ 'data' => {} })
    end
  end

  describe 'POST `create`' do
    it 'returns a default json payload' do
      post '/check_in/v0/patient_check_ins', params: { patient_check_ins: { id: '123aBc' } }

      expect(JSON.parse(response.body)).to eq({ 'data' => { 'status' => 'checked-in' } })
    end
  end
end
