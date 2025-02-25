# frozen_string_literal: true

require 'rails_helper'
require 'disability_compensation/factories/api_provider_factory'
require 'disability_compensation/providers/brd/lighthouse_staging_brd_provider'
require 'support/disability_compensation_form/shared_examples/brd_provider'
require 'lighthouse/service_exception'

RSpec.describe LighthouseStagingBRDProvider do
  let(:current_user) { build(:user, :loa3) }

  before do
    @provider = LighthouseStagingBRDProvider.new(current_user)
  end

  it_behaves_like 'brd provider'

  it 'retrieves separation locations from the Lighthouse API' do
    VCR.use_cassette('brd/separation_locations_staging') do
      response = @provider.get_separation_locations
      expect(response.separation_locations.length).to eq(327)
    end
  end
end
