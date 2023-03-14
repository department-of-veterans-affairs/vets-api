# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PatientCheckIns', type: :request do
  describe 'GET `show`' do
    it 'returns not implemented' do
      get '/check_in/v0/patient_check_ins/d602d9eb-9a31-484f-9637-13ab0b507e0d'

      expect(response.status).to eq(501)
    end
  end

  describe 'POST `create`' do
    it 'returns not implemented' do
      post '/check_in/v0/patient_check_ins'

      expect(response.status).to eq(501)
    end
  end
end
