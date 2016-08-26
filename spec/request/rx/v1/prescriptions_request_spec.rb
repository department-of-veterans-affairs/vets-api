require "rails_helper"

RSpec.describe "Prescriptions Integration", type: :request do
  before(:each) do
    allow_any_instance_of(ApplicationController).to receive(:authenticate).and_return(true)
  end

  it 'responds to GET #show' do
    VCR.use_cassette("prescriptions/1435525/show") do
      get "/rx/v1/prescriptions/1435525"
      expect(response).to be_success
      expect(response.body).to be_a(String)
      expect(response).to match_response_schema("prescription")
    end
  end

  it 'responds to GET #index with no parameters' do
    VCR.use_cassette("prescriptions/1435525/index/no_parameters") do
      get "/rx/v1/prescriptions"
      expect(response).to be_success
      expect(response.body).to be_a(String)
      expect(response).to match_response_schema("prescriptions")
    end
  end

  it 'responds to GET #index with refill_status=active' do
    VCR.use_cassette("prescriptions/1435525/index/refill_status_active") do
      get "/rx/v1/prescriptions?refill_status=active"
      expect(response).to be_success
      expect(response.body).to be_a(String)
      expect(response).to match_response_schema("prescriptions")
    end
  end

  it 'responds to GET #index with refill_status=unknown' do
    VCR.use_cassette("prescriptions/1435525/index/refill_status_unknown") do
      get "/rx/v1/prescriptions?refill_status=unknown"
      expect(response).to be_success
      expect(response.body).to be_a(String)
      expect(response).to match_response_schema("prescriptions_filtered")
    end
  end

  it 'responds to POST #refill' do
    VCR.use_cassette("prescriptions/refill_action") do
      patch "/rx/v1/prescriptions/1435525/refill"
      expect(response).to be_success
      expect(response.body).to be_empty
    end
  end

  context "nested resources" do
    it 'responds to GET #show of nested tracking resource' do
      VCR.use_cassette("prescriptions/1435525/tracking") do
        get "/rx/v1/prescriptions/1435525/trackings"
        expect(response).to be_success
        expect(response.body).to be_a(String)
        expect(response).to match_response_schema("trackings")
      end
    end
  end
end
