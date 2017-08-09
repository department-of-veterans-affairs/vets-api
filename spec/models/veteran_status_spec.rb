# frozen_string_literal: true
require 'rails_helper'
require 'common/exceptions'

describe VeteranStatus, skip_veteran_status: true do
  let(:user) { build :loa3_user }
  subject { VeteranStatus.for_user(user) }

  context 'with a valid response for a veteran' do
    use_vcr_cassette('emis/get_veteran_status/valid')

    describe '#veteran?' do
      it 'returns true' do
        expect(subject.veteran?).to be_truthy
      end
    end
  end

  context 'with a valid response for a non-veteran' do
    use_vcr_cassette('emis/get_veteran_status/valid_non_veteran')

    describe '#veteran' do
      it 'returns false' do
        expect(subject.veteran?).to be_falsey
      end
    end
  end

  describe 'veteran?' do
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
