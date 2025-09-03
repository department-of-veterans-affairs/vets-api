# frozen_string_literal: true

require 'rails_helper'

describe V2::Chip::ClaimsToken do
  subject { described_class }

  describe '.build' do
    it 'returns an instance of ClaimsToken' do
      expect(subject.build).to be_an_instance_of(V2::Chip::ClaimsToken)
    end
  end

  describe '#static' do
    it 'is an encoded base64 string' do
      base64_str = 'dmV0c2FwaVRlbXBVc2VyOlR6WTZERnJualBFOGR3eFVNYkZmOUhqYkZxUmltMk1nWHBNcE1' \
                   'jaVhKRlZvaHlVUlVKQWM3Vzk5cnBGemhmaDJCM3NWbm40'

      expect(subject.build.static).to eq(base64_str)
    end
  end

  describe '#tmp_api_id' do
    it 'has an api id' do
      expect(subject.build.tmp_api_id).to eq('2dcdrrn5zc')
    end
  end

  describe 'feature flag behavior' do
    context 'when check_in_experience_use_vaec_cie_endpoints flag is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with('check_in_experience_use_vaec_cie_endpoints').and_return(false)
      end

      it 'uses original settings' do
        token = subject.build
        expect(token.send(:tmp_api_id)).to eq(Settings.check_in.chip_api_v2.tmp_api_id)
        expect(token.send(:tmp_api_username)).to eq(Settings.check_in.chip_api_v2.tmp_api_username)
        expect(token.send(:tmp_api_user)).to eq(Settings.check_in.chip_api_v2.tmp_api_user)
      end

      it 'generates static token with original credentials' do
        base64_str = 'dmV0c2FwaVRlbXBVc2VyOlR6WTZERnJualBFOGR3eFVNYkZmOUhqYkZxUmltMk1nWHBNcE1' \
                     'jaVhKRlZvaHlVUlVKQWM3Vzk5cnBGemhmaDJCM3NWbm40'
        expect(subject.build.static).to eq(base64_str)
      end
    end

    context 'when check_in_experience_use_vaec_cie_endpoints flag is enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with('check_in_experience_use_vaec_cie_endpoints').and_return(true)
      end

      it 'uses v2 settings' do
        token = subject.build
        expect(token.send(:tmp_api_id)).to eq(Settings.check_in.chip_api_v2.tmp_api_id_v2)
        expect(token.send(:tmp_api_username)).to eq(Settings.check_in.chip_api_v2.tmp_api_username_v2)
        expect(token.send(:tmp_api_user)).to eq(Settings.check_in.chip_api_v2.tmp_api_user_v2)
      end

      it 'generates static token with v2 credentials' do
        # The static token will be different when using v2 credentials
        token = subject.build
        expect(token.static).not_to be_nil
        expect(token.static).to be_a(String)
        # Since the v2 credentials are the same in test.yml, the token should be the same
        base64_str = 'dmV0c2FwaVRlbXBVc2VyOlR6WTZERnJualBFOGR3eFVNYkZmOUhqYkZxUmltMk1nWHBNcE1' \
                     'jaVhKRlZvaHlVUlVKQWM3Vzk5cnBGemhmaDJCM3NWbm40'
        expect(token.static).to eq(base64_str)
      end
    end
  end
end
