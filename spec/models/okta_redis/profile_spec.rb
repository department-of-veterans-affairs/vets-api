# frozen_string_literal: true

require 'rails_helper'
require 'common/exceptions'

describe OktaRedis::Profile, skip_emis: true do
  let(:user) { build(:user, :loa3, uuid: '00u2fqgvbyT23TZNm2p7') }

  subject { described_class.with_user(user) }

  describe 'id' do
    it "returns the user's okta id" do
      with_okta_configured do
        VCR.use_cassette('okta/grants') do
          expect(subject.id).to eq('00u2fqgvbyT23TZNm2p7')
        end
      end
    end
  end
end
