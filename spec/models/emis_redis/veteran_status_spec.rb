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
end
