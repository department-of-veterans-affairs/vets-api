# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/veterans_health/client'

# rubocop:disable RSpec/FilePath
RSpec.describe Lighthouse::VeteransHealth::Client, :vcr do
  describe '#list_resource' do
    context 'with a multi-page response' do
      subject(:client) { described_class.new(32_000_225) }

      it 'returns all entries in the response' do
        response = client.list_resource('medications')
        expect(response.body['entry'].count).to match response.body['total']
      end
    end
  end
end
# rubocop:enable RSpec/FilePath
