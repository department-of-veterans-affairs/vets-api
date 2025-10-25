# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V0::Form214192 Committee validation', type: :request do
  include Committee::Rails::Test::Methods

  def committee_options
    @committee_options ||= {
      schema_path: Rails.public_path.join('openapi.json').to_s,
      prefix: '',
      strict_reference_validation: true,
      check_content_type: true
    }
  end

  let(:headers) do
    {
      'CONTENT_TYPE' => 'application/json',
      'ACCEPT' => 'application/json'
    }
  end

  let(:valid_payload) do
    {
      veteranInformation: {
        fullName: { first: 'John', last: 'Doe' },
        dateOfBirth: '1980-01-01',
        address: { street: '123 Main St', city: 'Anytown', state: 'CA', postalCode: '12345', country: 'USA' }
      },
      employmentInformation: {
        employerName: 'Acme Inc',
        employerAddress: { street: '456 Business Blvd', city: 'Chicago', state: 'IL', postalCode: '60601',
                           country: 'USA' },
        typeOfWorkPerformed: 'Developer',
        beginningDateOfEmployment: '2020-01-01'
      }
    }
  end

  let(:invalid_payload) do
    {
      veteranInformation: {
        fullName: { first: 'MissingLast' }
      }
    }
  end

  describe 'POST /v0/form214192' do
    it 'accepts a valid request and response conforms to schema' do
      post('/v0/form214192', params: valid_payload.to_json, headers:)

      expect(response).to have_http_status(:ok)
      assert_schema_conform(200)
    end

    it 'rejects an invalid request with 400 from Committee' do
      post('/v0/form214192', params: invalid_payload.to_json, headers:)

      expect(response).to have_http_status(:bad_request)
    end
  end
end
