# frozen_string_literal: true

require 'rails_helper'

describe EMISRedis::VeteranStatus, skip_va_profile: true do
  subject { described_class.for_user(user) }

  let(:user) { build(:user, :loa3) }
  let(:edipi) { '1005127153' }

  before do
    allow(user).to receive(:edipi).and_return(edipi)
  end

  describe 'veteran?' do
    context 'when the user doesnt have an edipi' do
      it 'raises VeteranStatus::NotAuthorized', :aggregate_failures do
        expect(user).to receive(:edipi).and_return(nil)

        expect { subject.veteran? }.to raise_error(described_class::NotAuthorized) do |e|
          expect(e.status).to eq 401
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
