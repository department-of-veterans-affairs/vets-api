# frozen_string_literal: true

require 'rails_helper'

describe Vet360::AddressValidation::Service do
  describe '#candidate' do
    it 'should return suggested addresses for a given address' do
      VCR.configure do |c|
        c.allow_http_connections_when_no_cassette = true
      end
      described_class.new.candidate(build(:vet360_address))
    end
  end
end
