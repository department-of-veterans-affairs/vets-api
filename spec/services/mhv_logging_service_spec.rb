# frozen_string_literal: true

require 'rails_helper'
require 'support/rx_client_helpers'

RSpec.describe MHVLoggingService do
  let(:mhv_user) do
    instance_double(User, uuid: 'user-uuid', mhv_correlation_id: '12345', mhv_last_signed_in: nil, loa3?: true,
                          user_account:)
  end
  let(:user_account) { instance_double(UserAccount, id: 1) }
  let(:login_service) { described_class.login(mhv_user) }
  let(:logout_service) { described_class.logout(mhv_user) }

  let(:authenticated_client) do
    MHVLogging::Client.new(session: { user_id: mhv_user.mhv_correlation_id,
                                      expires_at: Time.current + (60 * 60),
                                      token: '<SESSION_TOKEN>' })
  end

  before do
    # Setup Sidekiq test mode
    Sidekiq::Testing.fake!

    # Set up authenticated client stubbing
    allow(MHVLogging::Client).to receive(:new).and_return(authenticated_client)

    # Create a double for the authenticate method
    auth_object = double('authenticate')
    allow(authenticated_client).to receive(:authenticate).and_return(auth_object)
    allow(auth_object).to receive(:auditlogin)
    allow(auth_object).to receive(:auditlogout)
  end

  after do
    Sidekiq::Testing.fake!
    Sidekiq::Worker.clear_all
  end

  context 'with current_user not having logged in to MHV' do
    it 'enqueues an audit login job when not logged in' do
      expect(mhv_user.mhv_last_signed_in).to be_nil

      expect { login_service }.to change(MHV::AuditLoginJob.jobs, :size).by(1)
      expect(login_service).to be(true)

      job_args = MHV::AuditLoginJob.jobs.last['args']
      expect(job_args[0]).to eq(mhv_user.mhv_correlation_id)
      expect(job_args[1]).to eq(mhv_user.mhv_last_signed_in)
      expect(job_args[2]).to eq(mhv_user.user_account.id)
    end

    it 'does not enqueue a logout job when not logged in' do
      expect(mhv_user.mhv_last_signed_in).to be_nil

      expect { logout_service }.not_to change(MHV::AuditLogoutJob.jobs, :size)
      expect(logout_service).to be(false)
    end
  end

  context 'with current_user having already logged in to MHV' do
    let(:signed_in_time) { Time.current }
    let(:mhv_user) do
      instance_double(
        User,
        uuid: 'user-uuid',
        mhv_correlation_id: '12345',
        mhv_last_signed_in: signed_in_time,
        loa3?: true,
        user_account:
      )
    end

    it 'does not enqueue login job when already logged in' do
      expect(mhv_user.mhv_last_signed_in).to eq(signed_in_time)

      expect { login_service }.not_to change(MHV::AuditLoginJob.jobs, :size)
      expect(login_service).to be(false)
    end

    it 'enqueues an audit logout job when logged in' do
      expect(mhv_user.mhv_last_signed_in).to eq(signed_in_time)

      expect { logout_service }.to change(MHV::AuditLogoutJob.jobs, :size).by(1)
      expect(logout_service).to be(true)

      job_args = MHV::AuditLogoutJob.jobs.last['args']
      expect(job_args[0]).to eq(mhv_user.mhv_correlation_id)
      expect(job_args[1]).to eq(signed_in_time.iso8601)
      expect(job_args[2]).to eq(mhv_user.user_account.id)
    end
  end

  context 'with delegate user having MHV credentials' do
    let(:mhv_correlation_id) { '12345' }
    let(:user_uuid1) { 'user1-uuid' }
    let(:user_uuid2) { 'user2-uuid' }
    let(:delegate_user) do
      instance_double(User, uuid: user_uuid2, mhv_correlation_id:, mhv_last_signed_in: nil, loa3?: true)
    end
    let(:primary_user) do
      instance_double(User, uuid: user_uuid1, mhv_correlation_id:, mhv_last_signed_in: nil, loa3?: true, user_account:)
    end
    let(:login_service) { described_class.login(primary_user) }
    let(:logout_service) { described_class.logout(primary_user) }

    it 'passes the correct parameters to AuditLoginJob' do
      expect { login_service }.to change(MHV::AuditLoginJob.jobs, :size).by(1)

      job_args = MHV::AuditLoginJob.jobs.last['args']
      expect(job_args[0]).to eq(mhv_correlation_id)
      expect(job_args[1]).to be_nil
      expect(job_args[2]).to eq(user_account.id)
    end

    it 'passes the correct parameters to AuditLogoutJob' do
      # Set up signed-in time
      allow(primary_user).to receive(:mhv_last_signed_in).and_return(Time.current)

      expect { logout_service }.to change(MHV::AuditLogoutJob.jobs, :size).by(1)

      job_args = MHV::AuditLogoutJob.jobs.last['args']
      expect(job_args[0]).to eq(mhv_correlation_id)
      expect(job_args[1]).to eq(primary_user.mhv_last_signed_in.iso8601)
      expect(job_args[2]).to eq(user_account.id)
    end
  end
end
