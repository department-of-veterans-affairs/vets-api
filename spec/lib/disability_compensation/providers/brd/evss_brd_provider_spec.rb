# frozen_string_literal: true

require 'rails_helper'
require 'disability_compensation/factories/api_provider_factory'
require 'disability_compensation/providers/brd/evss_brd_provider'
require 'support/disability_compensation_form/shared_examples/brd_provider'

RSpec.describe EvssBRDProvider do
  let(:current_user) do
    create(:user)
  end

  let(:auth_headers) do
    EVSS::AuthHeaders.new(current_user).to_h
  end

  before do
    Flipper.disable(ApiProviderFactory::FEATURE_TOGGLE_BRD)
  end

  after do
    Flipper.disable(ApiProviderFactory::FEATURE_TOGGLE_BRD)
  end

  it_behaves_like 'brd provider'

  it 'retrieves separation locations from the EVSS API' do
    VCR.use_cassette('evss/reference_data/get_intake_sites', match_requests_on: %i[uri method body]) do
      provider = EvssBRDProvider.new(current_user)
      response = provider.get_separation_locations
      expect(response['separation_locations'].length).to eq(324)
    end
  end
end
