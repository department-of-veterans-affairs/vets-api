# frozen_string_literal: true

require_relative '../../../rails_helper'

RSpec.describe AccreditedRepresentativePortal::V0::PowerOfAttorneyRequestsController, type: :request do
  let(:test_user) { create(:representative_user) }
  let(:poa_request_details_id) { '123' }
  let(:poa_details_mock_data) do
    {
      "status" => "Testing"
    }
  end

  before do
    Flipper.enable(:accredited_representative_portal_pilot)
    
    login_as(test_user)

    # stub the service call, sending in the id and returning the mock data
    allow(AccreditedRepresentativePortal::PoaRequestDetailsService).to receive(:new).with(poa_request_details_id).and_return(
      instance_double(AccreditedRepresentativePortal::PoaRequestDetailsService, call: poa_details_mock_data)
    )
  end

  it 'returns the details of a power of attorney request' do
    get("/accredited_representative_portal/v0/power_of_attorney_requests/#{poa_request_details_id}")
    expect(response.status).to eq(200)
    expect(JSON.parse(response.body)).to eq(poa_details_mock_data)
  end
end
