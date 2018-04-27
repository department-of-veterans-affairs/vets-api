# frozen_string_literal: true

require 'rails_helper'

describe EVSS::PCIUAddress::Service do
  let(:user) { build(:user, :loa3) }
  subject { described_class.new(user) }

  describe '#get_address' do
    context 'with a 200 response' do
      it 'returns a users mailing address' do
        VCR.use_cassette('evss/pciu_address/address') do
          response = subject.get_address
          expect(response).to be_ok
        end
      end
    end
  end

  describe '#update_address' do
    context 'with a valid address update' do
      let(:update_address) { build(:pciu_domestic_address) }

      it 'updates and returns a users mailing address' do
        VCR.use_cassette('evss/pciu_address/address_update') do
          response = subject.update_address(update_address)
          expect(response).to be_ok
        end
      end
    end

    context 'with evss internal server error' do
      let(:update_address) { build(:pciu_domestic_address) }

      it 'returns a users mailing address' do
        VCR.use_cassette('evss/pciu_address/update_invalid') do
          expect { subject.update_address(update_address) }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end
  end
end
