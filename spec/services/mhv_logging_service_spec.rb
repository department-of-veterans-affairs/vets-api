# frozen_string_literal: true

require 'rails_helper'
require 'support/rx_client_helpers'

RSpec.describe MHVLoggingService do
  let(:login_service) { described_class.login(mhv_user) }

  let(:logout_service) { described_class.logout(mhv_user) }

  let(:authenticated_client) do
    MHVLogging::Client.new(session: { user_id: mhv_user.mhv_correlation_id,
                                      expires_at: Time.current + (60 * 60),
                                      token: '<SESSION_TOKEN>' })
  end

  before do
    Sidekiq::Testing.inline!
    allow(MHVLogging::Client).to receive(:new).and_return(authenticated_client)
  end

  after do
    Sidekiq::Testing.fake!
  end

  context 'with current_user not having logged in to MHV' do
    let(:mhv_user) { create(:user, :mhv, :mhv_not_logged_in) }

    it 'posts audit log when not logged in' do
      allow(Flipper).to receive(:enabled?).with(:mhv_medications_migrate_to_api_gateway).and_return(false)

      VCR.use_cassette('mhv_logging_client/audits/submits_an_audit_log_for_signing_in') do
        expect(mhv_user.mhv_last_signed_in).to be_nil
        expect(login_service).to be(true)
        expect(User.find(mhv_user.uuid).mhv_last_signed_in).to be_a(Time)
      end
    end

    it 'does not logout when not logged in' do
      expect(mhv_user.mhv_last_signed_in).to be_nil
      expect(logout_service).to be(false)
      expect(mhv_user.mhv_last_signed_in).to be_nil
    end
  end

  context 'with current_user having already logged in to MHV' do
    let(:mhv_user) { create(:user, :mhv) }

    it 'posts audit log when not logged in' do
      expect(mhv_user.mhv_last_signed_in).to be_a(Time)
      expect(login_service).to be(false)
      expect(mhv_user.mhv_last_signed_in).to be_a(Time)
    end

    it 'does not logout when not logged in' do
      allow(Flipper).to receive(:enabled?).with(:mhv_medications_migrate_to_api_gateway).and_return(false)

      VCR.use_cassette('mhv_logging_client/audits/submits_an_audit_log_for_signing_out') do
        expect(mhv_user.mhv_last_signed_in).to be_a(Time)
        expect(logout_service).to be(true)
        expect(User.find(mhv_user.uuid).mhv_last_signed_in).to be_nil
      end
    end
  end
end
