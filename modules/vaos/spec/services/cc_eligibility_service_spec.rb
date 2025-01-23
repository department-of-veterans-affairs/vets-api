# frozen_string_literal: true

require 'rails_helper'

describe VAOS::CCEligibilityService do
  subject { described_class.new(user) }

  let(:user) { build(:user, :vaos) }
  let(:service_type) { 'PrimaryCare' }

  before { allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token') }

  describe '#get_eligibility', :skip_mvi do
    it 'gets an eligibility of true' do
      VCR.use_cassette('vaos/cc_eligibility/get_eligibility_true', match_requests_on: %i[method path query]) do
        response = subject.get_eligibility(service_type)
        expect(response[:data].eligible).to be(true)
      end
    end

    it 'gets an eligibility of false' do
      VCR.use_cassette('vaos/cc_eligibility/get_eligibility_false', match_requests_on: %i[method path query]) do
        response = subject.get_eligibility(service_type)
        expect(response[:data].eligible).to be(false)
      end
    end

    context 'invalid service_type' do
      let(:service_type) { 'NotAType' }

      it 'handles 400 error appropriately' do
        VCR.use_cassette('vaos/cc_eligibility/get_eligibility_400', match_requests_on: %i[method path query]) do
          expect { subject.get_eligibility(service_type) }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end
  end
end
