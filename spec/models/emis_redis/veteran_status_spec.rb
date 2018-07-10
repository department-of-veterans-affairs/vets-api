# frozen_string_literal: true

require 'rails_helper'
require 'common/exceptions'

describe EMISRedis::VeteranStatus, skip_emis: true do
  let(:user) { build(:user, :loa3) }
  subject { described_class.for_user(user) }

  describe 'veteran?' do
    context 'with a valid response for a veteran' do
      it 'returns true' do
        VCR.use_cassette('emis/get_veteran_status/valid') do
          expect(subject.veteran?).to be_truthy
        end
      end
    end

    context 'with a valid response for a non-veteran' do
      it 'returns false' do
        VCR.use_cassette('emis/get_veteran_status/valid_non_veteran') do
          expect(subject.veteran?).to be_falsey
        end
      end
    end

    context 'when a record can not be found' do
      it 'raises VeteranStatus::RecordNotFound' do
        VCR.use_cassette('emis/get_veteran_status/missing_edipi') do
          expect do
            subject.veteran?
          end.to raise_error(described_class::RecordNotFound)
        end
      end
    end

    context 'when a Common::Client::Errors::ClientError occurs' do
      it 'raises the error' do
        allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(Common::Client::Errors::ClientError)
        expect do
          subject.veteran?
        end.to raise_error(Common::Client::Errors::ClientError)
      end
    end
  end

  describe 'title38_status' do
    context 'with a valid response for a veteran' do
      it 'returns true' do
        VCR.use_cassette('emis/get_veteran_status/valid') do
          expect(subject.title38_status).to eq('V1')
        end
      end
    end

    context 'with a valid response for a non-veteran' do
      it 'returns false' do
        VCR.use_cassette('emis/get_veteran_status/valid_non_veteran') do
          expect(subject.title38_status).to eq('V4')
        end
      end
    end
  end

  describe 'pre_911_combat_deployment?' do
    context 'with a response of "N"' do
      it 'returns false' do
        VCR.use_cassette('emis/get_veteran_status/valid') do
          expect(subject.pre_911_combat_deployment?).to eq false
        end
      end
    end

    context 'with an empty response' do
      before do
        allow(subject).to receive_message_chain(:validated_response, :pre911_deployment_indicator) { nil }
      end

      it 'returns nil' do
        expect(subject.pre_911_combat_deployment?).to be_nil
      end
    end

    context 'with an unexpected response' do
      before do
        allow(subject).to receive_message_chain(:validated_response, :pre911_deployment_indicator) { 'random' }
      end

      it 'returns nil' do
        expect(subject.pre_911_combat_deployment?).to be_nil
      end
    end
  end

  describe 'post_911_combat_deployment?' do
    context 'with a response of "Y"' do
      it 'returns true' do
        VCR.use_cassette('emis/get_veteran_status/valid') do
          expect(subject.post_911_combat_deployment?).to eq true
        end
      end
    end
  end
end
