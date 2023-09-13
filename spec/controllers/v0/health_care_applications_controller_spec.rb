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

  describe '#download_pdf' do
    let(:response_pdf) { Rails.root.join 'tmp', 'pdfs', '10-10EZ_John_Smith.pdf' }
    let(:expected_pdf) { Rails.root.join 'spec', 'fixtures', 'pdf_fill', '10-10EZ', 'unsigned', 'simple.pdf' }

    it 'downloads a pdf' do
      post :download_pdf, params: JSON.parse(hca_request)

      File.open(response_pdf, 'wb+') { |f| f.write(response.body) }

      expect(response).to have_http_status(:ok)

      expect(
        pdfs_fields_match?(response_pdf, expected_pdf)
      ).to eq(true)
    end
  end
end
