# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Veteran Identifier Endpoint', type: :request do
  let(:headers) do
    { 'X-VA-SSN': '796-04-3735',
      'X-VA-First-Name': 'WESLEY',
      'X-VA-Last-Name': 'FORD',
      'X-Consumer-Username': 'TestConsumer',
      'X-VA-Birth-Date': '1986-05-06T00:00:00+00:00',
      'X-VA-Gender': 'M' }
  end

  describe 'veteran identifier' do
    let(:path) { '/services/claims/v2/veteran-identifier' }

    it 'returns an ICN' do
      get path, headers: headers
      icn = JSON.parse(response.body)['icn']
      expect(icn).to eq('123456789')
      expect(response.status).to eq(200)
    end
  end
end
