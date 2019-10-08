# frozen_string_literal: true

require 'rails_helper'

describe Vet360::AddressValidation::Service do
  let(:address) { build(:vet360_address) }

  describe '#candidate' do
    it 'should return suggested addresses for a given address' do
      address.address_line1 = '5 Stoddard Ct'
      address.city = 'Sparks Glencoe'
      address.state_code = 'MD'
      address.zip_code = '21152'

      VCR.use_cassette(
        'vet360/address_validation/candidate_one_match'
      ) do
        res = described_class.new.candidate(address)
        binding.pry; fail
      end
    end
  end
end
