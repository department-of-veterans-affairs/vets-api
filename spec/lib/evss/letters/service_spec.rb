# frozen_string_literal: true
require 'rails_helper'

describe EVSS::Letters::Service do
  describe '.find_by_user' do
    let(:user) { build(:loa3_user) }
    let(:auth_headers) { EVSS::AuthHeaders.new(user).to_h }

    subject { described_class.new(auth_headers) }

    describe '#get_letters' do
      context 'with a valid evss response' do
        it 'returns creates a letter response object' do
          VCR.use_cassette('evss/letters/letters') do
            response = subject.get_letters
            expect(response).to be_ok
            expect(response).to be_a(EVSS::Letters::LettersResponse)
            expect(response.letters.count).to eq(8)
            expect(response.letters.first.as_json).to eq('name' => 'Commissary Letter', 'letter_type' => 'commissary')
          end
        end
      end
    end
  end
end
