# frozen_string_literal: true

require 'rails_helper'
require 'mvi/orch_search_service'

describe MVI::OrchSearchService do
  let(:user) { build(:user, :loa3, user_hash) }

  describe '.find_profile with attributes' do
    context 'valid request' do
      let(:user_hash) do
        {
          first_name: 'MARK',
          last_name: 'WEBB',
          middle_name: '',
          birth_date: '1950-10-04',
          ssn: '796104437',
          dslogon_edipi: '1013590059'
        }
      end

      it 'calls the find profile with an orchestrated search', run_at: 'Thu, 06 Feb 2020 23:59:36 GMT' do
        allow(SecureRandom).to receive(:uuid).and_return('b4d9a901-8f2f-46c0-802f-3eeb99c51dfb')
        allow(Socket).to receive(:ip_address_list).and_return([Addrinfo.ip('1.1.1.1')])

        VCR.use_cassette('mvi/find_candidate/orch_search_with_attributes', VCR::MATCH_EVERYTHING) do
          Settings.mvi.vba_orchestration = true
          response = described_class.new.find_profile(user)
          expect(response.status).to eq('OK')
          expect(response.profile.icn).to eq('1008709396V637156')
          Settings.mvi.vba_orchestration = false
        end
      end
    end

    context 'with an invalid user' do
      let(:user) { build(:user, :loa1) }

      it 'raises an unprocessable entity error' do
        expect { described_class.new.find_profile(user) }.to raise_error do |error|
          expect(error).to be_a(Common::Exceptions::UnprocessableEntity)
          expect(error.errors.first.source).to eq('OrchSearchService')
          expect(error.errors.first.detail).to eq('User is invalid or missing edipi')
        end
      end
    end
  end
end
