# frozen_string_literal: true

require 'rails_helper'
require 'common/exceptions'

describe OktaRedis::App, skip_emis: true do
  let(:user) { build(:user, :loa3, uuid: '00u2fqgvbyT23TZNm2p7') }
  let(:from_okta) { { id: '0oa2ey2m6kEL2897N2p7', title: 'TestGrantRevoke' } }

  subject { described_class.with_id(from_okta[:id]) }

  %i[id title].each do |body_attr|
    describe body_attr.to_s do
      it 'returns the correct app attribute' do
        with_okta_configured do
          VCR.use_cassette('okta/grants') do
            expect(subject.send(body_attr)).to eq(from_okta[body_attr])
          end
        end
      end
    end
  end

  describe 'fetch_grants' do
    context 'with user' do
      before do
        subject.user = user
      end

      it 'returns array of grants with for this app' do
        with_okta_configured do
          VCR.use_cassette('okta/grants') do
            grants = subject.fetch_grants
            expect(grants).to be_an(Array)
            expect(grants[0]).to be_a(Hash)
            expect(
              grants[0]['_links']['app']['href'].split('/').last
            ).to eq(from_okta[:id])
          end
        end
      end
    end

    context 'without user' do
      it 'raises an error' do
        expect { subject.fetch_grants }.to raise_error(RuntimeError)
      end
    end
  end
end
