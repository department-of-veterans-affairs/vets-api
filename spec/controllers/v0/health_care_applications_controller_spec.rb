# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::HealthCareApplicationsController, type: :controller do
  let(:hca_request) { file_fixture('forms/healthcare_application_request.json').read }
  let(:hca_response) { JSON.parse(file_fixture('forms/healthcare_application_response.json').read) }

  describe '#create' do
    it 'creates a pending application' do
      post :create, params: JSON.parse(hca_request)

      json = JSON.parse(response.body)
      expect(json['attributes']).to eq(hca_response['attributes'])
    end
  end
end
