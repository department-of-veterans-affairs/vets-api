# frozen_string_literal: true

require 'rails_helper'

describe OktaRedis::Grants, skip_emis: true do
  subject { described_class.with_user(user) }

  let(:user) { build(:user, :loa3, uuid: '1847a3eb4b904102882e24e4ddf12ff3') }

  describe 'all' do
    context 'with response from okta' do
      it 'returns array of hashes' do
        with_okta_configured do
          VCR.use_cassette('okta/grants') do
            expect(subject.all).to be_an(Array)
            expect(subject.all[0]).to be_a(Hash)
          end
        end
      end
    end
  end

  describe 'delete_grants' do
    it 'returns true for successful deletion' do
      with_okta_configured do
        VCR.use_cassette('okta/delete_grants', allow_playback_repeats: true) do
          ids = [subject.all.first['id']]
          expect(subject.delete_grants(ids)).to be_truthy
        end
      end
    end
  end

  describe 'delete_grant' do
    context 'raises on error' do
      it 'raises' do
        with_okta_configured do
          VCR.use_cassette('okta/delete_grants_error') do
            expect { subject.delete_grant('123') }.to raise_error(RuntimeError)
          end
        end
      end
    end
  end
end
