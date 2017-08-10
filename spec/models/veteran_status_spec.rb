# frozen_string_literal: true
require 'rails_helper'
require 'common/exceptions'

describe VeteranStatus, skip_veteran_status: true do
  let(:user) { build :loa3_user }
  subject { VeteranStatus.for_user(user) }

  describe '#post911_combat_indicator' do
    context 'with a valid response' do
      it 'returns true' do
        VCR.use_cassette('emis/get_veteran_status/post911_combat') do
          expect(subject.post911_combat_indicator?).to eq(true)
        end
      end
    end

    context 'with a valid response that doesnt have post 911 combat' do
      it 'returns false' do
        VCR.use_cassette('emis/get_veteran_status/valid') do
          expect(subject.post911_combat_indicator?).to eq(false)
        end
      end
    end
  end


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
          end.to raise_error(VeteranStatus::RecordNotFound)
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
end
