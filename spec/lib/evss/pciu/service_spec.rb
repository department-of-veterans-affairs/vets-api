# frozen_string_literal: true

require 'rails_helper'

describe EVSS::PCIU::Service do
  let(:user) { build(:user, :loa3) }
  subject { described_class.new(user) }

  describe '#email_address', focus: true do
    context 'when successful' do
      it 'returns a status of 200' do
        VCR.use_cassette('evss/pciu/service') do
          response = subject.email_address

          expect(response).to be_ok
        end
      end

      it 'returns a users email address value and effective_date' do
        VCR.use_cassette('evss/pciu/service') do
          response = subject.email_address

          expect(response.email_address.keys).to contain_exactly 'effective_date', 'value'
        end
      end
    end
  end
end
