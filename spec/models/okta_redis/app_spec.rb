# frozen_string_literal: true

require 'rails_helper'

describe OktaRedis::App, skip_emis: true do
  subject { described_class.with_id(from_okta[:id]) }

  let(:user) { build(:user, :loa3, uuid: '1847a3eb4b904102882e24e4ddf12ff3') }
  let(:from_okta) { { id: '0oa2ey2m6kEL2897N2p7', title: 'TestGrantRevoke' } }

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

  describe '#cache_key' do
    context 'with multiple apps' do
      let(:user) { User.new uuid: '1847a3eb4b904102882e24e4ddf12ff3' }
      let(:apps) do
        user.okta_grants.all.map { |grant| grant['_links']['app']['href'].split('/').last }.uniq!
      end

      it 'uses the correct cache key' do
        with_okta_configured do
          VCR.use_cassette('okta/multiple_apps') do
            app = described_class.with_id(apps[0])
            expected_key = "#{app.class::CLASS_NAME}.#{apps[0]}"
            expect(app.send(:cache_key)).to eq(expected_key)
          end
        end
      end

      it 'has a unique key' do
        with_okta_configured do
          VCR.use_cassette('okta/multiple_apps') do
            app1 = described_class.with_id(apps[0])
            app2 = described_class.with_id(apps[1])
            expect(app1.send(:cache_key)).not_to eq(app2.send(:cache_key))
          end
        end
      end

      context 'with user assigned' do
        it 'does not affect the key' do
          with_okta_configured do
            VCR.use_cassette('okta/multiple_apps') do
              app = described_class.with_id(apps[0])
              app.user = user
              user_based_key = "#{app.class::CLASS_NAME}.#{user.uuid}"
              expect(app.send(:cache_key)).not_to eq(user_based_key)
            end
          end
        end
      end
    end
  end
end
