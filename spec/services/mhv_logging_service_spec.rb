# frozen_string_literal: true
require 'rails_helper'
require 'support/rx_client_helpers'

RSpec.describe MHVLoggingService do
  subject(:login_service) { described_class.login(mhv_user) }
  subject(:logout_service) { described_class.logout(mhv_user) }

  before(:each) do
    Sidekiq::Testing.inline!
  end

  after(:each) do
    Sidekiq::Testing.fake!
  end

  let(:authenticated_client) do
    MHVLogging::Client.new(session: { user_id: mhv_user.mhv_correlation_id,
                                      expires_at: Time.current + 60 * 60,
                                      token: '<SESSION_TOKEN>' })
  end

  before(:each) { allow(MHVLogging::Client).to receive(:new).and_return(authenticated_client) }

  context 'with current_user not having logged in to MHV' do
    let(:session) { create(:loa3_session) }
    let(:mhv_user) { create(:mhv_user, :mhv_not_logged_in, uuid: session.uuid, session: session) }

    it 'posts audit log when not logged in' do
      VCR.use_cassette('mhv_logging_client/audits/submits_an_audit_log_for_signing_in') do
        expect(mhv_user.mhv_last_signed_in).to be_nil
        # TODO : fix this expectation - the async AuditLoginJob only keys off of
        # user.uuid which ultimately calls into the mvi model which will have a nil session
        expect(login_service).to eq(true)
        expect(User.find(mhv_user.uuid).mhv_last_signed_in).to be_a(Time)
      end
    end

    it 'does not logout when not logged in' do
      expect(mhv_user.mhv_last_signed_in).to be_nil
      expect(logout_service).to eq(false)
      expect(mhv_user.mhv_last_signed_in).to be_nil
    end
  end

  context 'with current_user having already logged in to MHV' do
    let(:session) { create(:loa3_session) }
    let(:mhv_user) { create(:mhv_user, uuid: session.uuid, session: session) }

    it 'posts audit log when not logged in' do
      expect(mhv_user.mhv_last_signed_in).to be_a(Time)
      expect(login_service).to eq(false)
      expect(mhv_user.mhv_last_signed_in).to be_a(Time)
    end

    it 'does not logout when not logged in' do
      VCR.use_cassette('mhv_logging_client/audits/submits_an_audit_log_for_signing_out') do
        expect(mhv_user.mhv_last_signed_in).to be_a(Time)
        expect(logout_service).to eq(true)
        expect(User.find(mhv_user.uuid).mhv_last_signed_in).to be_nil
      end
    end
  end
end
