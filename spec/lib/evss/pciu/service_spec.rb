# frozen_string_literal: true

require 'rails_helper'

describe EVSS::PCIU::Service do
  let(:user) { build(:user, :loa3) }
  subject { described_class.new(user) }

  describe '#get_email_address' do
    context 'when successful' do
      it 'returns a status of 200' do
        VCR.use_cassette('evss/pciu/email') do
          response = subject.get_email_address

          expect(response).to be_ok
        end
      end

      it 'returns a users email address value and effective_date' do
        VCR.use_cassette('evss/pciu/email') do
          response = subject.get_email_address

          expect(response.email_address.keys).to contain_exactly 'effective_date', 'value'
        end
      end
    end
  end

  describe '#get_primary_phone' do
    context 'when successful' do
      it 'returns a status of 200' do
        VCR.use_cassette('evss/pciu/primary_phone') do
          response = subject.get_primary_phone

          expect(response).to be_ok
        end
      end

      it 'returns a users primary phone number, extension and country code' do
        VCR.use_cassette('evss/pciu/primary_phone') do
          response = subject.get_primary_phone

          expect(response.attributes.keys).to include :country_code, :number, :extension
        end
      end
    end
  end
end
