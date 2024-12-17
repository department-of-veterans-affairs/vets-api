# frozen_string_literal: true

require_relative '../../../rails_helper'

RSpec.describe AccreditedRepresentativePortal::V0::PowerOfAttorneyRequestsController, type: :request do
  let(:test_user) { create(:representative_user) }
  let(:poa_request) { create(:power_of_attorney_request) }
  let(:poa_requests) { create_list(:power_of_attorney_request, 3) }

  before do
    Flipper.enable(:accredited_representative_portal_pilot)
    login_as(test_user)
  end

  describe 'GET /accredited_representative_portal/v0/power_of_attorney_requests' do
    it 'returns the list of power of attorney requests' do
      poa_requests

      get('/accredited_representative_portal/v0/power_of_attorney_requests')

      expect(response).to have_http_status(:ok)
      parsed_response = JSON.parse(response.body)

      expected_response = AccreditedRepresentativePortal::PowerOfAttorneyRequestSerializer
                          .new(poa_requests)
                          .serializable_hash

      expect(deep_stringify(parsed_response)).to eq(deep_stringify(expected_response))
    end
  end

  describe 'GET /accredited_representative_portal/v0/power_of_attorney_requests/:id' do
    it 'returns the details of a specific power of attorney request' do
      get("/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request.id}")

      expect(response).to have_http_status(:ok)
      parsed_response = JSON.parse(response.body)

      expected_response = AccreditedRepresentativePortal::PowerOfAttorneyRequestSerializer
                          .new(poa_request)
                          .serializable_hash

      expect(deep_stringify(parsed_response)).to eq(deep_stringify(expected_response))
    end
  end

  def deep_stringify(value)
    case value
    when Hash
      value.each_with_object({}) do |(k, v), result|
        result[k.to_s] = deep_stringify(v) # Stringify keys and recursively process values
      end
    when Array
      value.map { |v| deep_stringify(v) } # Recursively process arrays
    when Symbol
      value.to_s # Convert symbols to strings
    else
      value # Leave other primitives (e.g., strings, numbers, nil) as is
    end
  end
end
