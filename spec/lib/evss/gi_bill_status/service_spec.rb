# frozen_string_literal: true
require 'rails_helper'

describe EVSS::GiBillStatus::Service do
  describe '.find_by_user' do
    let(:user) { build(:loa3_user) }
    let(:auth_headers) { EVSS::AuthHeaders.new(user).to_h }

    subject { described_class.new(auth_headers) }

    describe '#get_gi_bill_status' do
      context 'with a valid evss response' do
        it 'returns a valid response object' do
          VCR.use_cassette('evss/gi_bill_status/gi_bill_status') do
            response = subject.get_gi_bill_status
            puts response.ok?
            expect(response).to be_ok
          end
        end
      end
    end
  end
end
