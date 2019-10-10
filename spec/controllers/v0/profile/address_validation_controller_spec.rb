# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::Profile::AddressValidationController, type: :controller do
  let(:user) { FactoryBot.build(:user) }
  let(:address) { build(:vet360_address) }

  before(:each) do
    sign_in_as(user)
  end

  describe '#create' do
    context 'with a found address' do
      it 'should return suggested addresses for a given address' do
        address.address_line1 = '5 Stoddard Ct'
        address.city = 'Sparks Glencoe'
        address.state_code = 'MD'
        address.zip_code = '21152'

        VCR.use_cassette(
          'vet360/address_validation/candidate_one_match',
          VCR::MATCH_EVERYTHING
        ) do
          post(:create, params: address.to_h)
          binding.pry; fail
        end
      end
    end
  end
end
