# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V1::PatientCheckIns', type: :request do
  describe 'POST `create`' do
    it 'returns not implemented' do
      post '/check_in/v1/patient_check_ins'

      expect(response.status).to eq(501)
    end
  end

  describe 'GET `show`' do
    it 'returns not implemented' do
      get '/check_in/v1/patient_check_ins/1234'

      expect(response.status).to eq(501)
    end
  end
end
