# frozen_string_literal: true

require 'rails_helper'

describe OktaRedis::Profile, skip_emis: true do
  subject { described_class.with_user(user) }

  context 'ial2' do
    let(:user) { build(:user, :loa3, uuid: '1847a3eb4b904102882e24e4ddf12ff3', icn: '1013062086V794840') }

    describe 'id by uuid' do
      it "returns the user's okta id" do
        with_okta_configured do
          with_settings(Settings.oidc, base_api_profile_key_icn: false) do
            VCR.use_cassette('okta/grants') do
              expect(subject.id).to eq('00u2fqgvbyT23TZNm2p7')
            end
          end
        end
      end
    end

    describe 'id by icn' do
      it "returns the user's okta id" do
        with_okta_configured do
          with_settings(Settings.oidc, base_api_profile_key_icn: true) do
            VCR.use_cassette('okta/user-search') do
              VCR.use_cassette('okta/grants') do
                expect(subject.id).to eq('00u2fqgvbyT23TZNm2p7')
              end
            end
          end
        end
      end
    end
  end

  context 'ial2 not found' do
    let(:user) { build(:user, :loa3, uuid: '1847a3eb4b904102882e24e4ddf12ff3', icn: 'BAD1013062086V794840') }

    describe 'id by icn not found' do
      it "returns the user's okta id" do
        with_okta_configured do
          with_settings(Settings.oidc, base_api_profile_key_icn: true) do
            VCR.use_cassette('okta/user-search-empty') do
              expect { subject.id }.to raise_error(Common::Exceptions::RecordNotFound, 'Record not found')
            end
          end
        end
      end
    end
  end

  context 'ial1' do
    let(:user) { build(:user, :loa3, uuid: '1847a3eb4b904102882e24e4ddf12ff3a', icn: nil) }

    before do
      allow(user).to receive(:icn).and_return(nil)
    end

    describe 'error when nil' do
      it "returns an error with the user's uuid if icn is nil" do
        with_okta_configured do
          with_settings(Settings.oidc, base_api_profile_key_icn: true) do
            VCR.use_cassette('okta/grants') do
              expect { subject.id }.to raise_error(Common::Exceptions::RecordNotFound, 'Record not found')
            end
          end
        end
      end
    end
  end
end
