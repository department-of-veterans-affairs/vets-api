# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccreditedRepresentativePortal::PoaRequestDetailsService do
  subject { described_class.new(poa_request_details_id) }

  let(:poa_request_details_id) { '123' }

  describe '#call' do
    it 'returns the details of a power of attorney request' do
      # for now the service returns hard coded mock data, this test will grow as the service becomes more implemented
      expect(subject.call[:status]).to eq('Pending') # valid structure confirms we are returning mock data as expected
    end
  end
end
