# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MHVLoggingService do
  let(:mhv_correlation_id) { '12345' }
  let(:user) do
    instance_double(User,
                    uuid: 'user-uuid',
                    mhv_correlation_id:,
                    mhv_last_signed_in: nil,
                    loa3?: true)
  end

  let(:authenticated_client) do
    MHVLogging::Client.new(session: { user_id: mhv_correlation_id })
  end

  before do
    Sidekiq::Testing.fake!

    allow(MHVLogging::Client).to receive(:new).and_return(authenticated_client)
    allow(authenticated_client).to receive(:authenticate).and_return(authenticated_client)
    allow(authenticated_client).to receive(:auditlogin)
    allow(authenticated_client).to receive(:auditlogout)
  end

  after do
    Sidekiq::Testing.fake!
    Sidekiq::Worker.clear_all
  end

  describe '.login' do
    context 'with valid user' do
      before do
        allow(user).to receive(:save).and_return(true)
        allow(user).to receive(:mhv_last_signed_in=)
      end

      it 'enqueues login job and updates user' do
        expect(user).to receive(:mhv_last_signed_in=) do |time|
          expect(time).to be_a(ActiveSupport::TimeWithZone)
        end
        expect(user).to receive(:save)

        expect { described_class.login(user) }.to change(MHV::AuditLoginJob.jobs, :size).by(1)

        job = MHV::AuditLoginJob.jobs.last
        expect(job['args']).to eq([mhv_correlation_id])
      end
    end

    context 'with already logged in user' do
      let(:user) do
        instance_double(User,
                        uuid: 'user-uuid',
                        mhv_correlation_id:,
                        mhv_last_signed_in: Time.current,
                        loa3?: true)
      end

      it 'does not enqueue job or update user' do
        expect(user).not_to receive(:mhv_last_signed_in=)
        expect(user).not_to receive(:save)

        expect { described_class.login(user) }.not_to change(MHV::AuditLoginJob.jobs, :size)
      end
    end
  end

  describe '.logout' do
    let(:signed_in_time) { Time.current }
    let(:user) do
      instance_double(User,
                      uuid: 'user-uuid',
                      mhv_correlation_id:,
                      mhv_last_signed_in: signed_in_time)
    end

    context 'with signed in user' do
      before do
        allow(user).to receive(:save).and_return(true)
        allow(user).to receive(:mhv_last_signed_in=)
      end

      it 'enqueues logout job and updates user' do
        expect(user).to receive(:mhv_last_signed_in=).with(nil)
        expect(user).to receive(:save)

        expect { described_class.logout(user) }.to change(MHV::AuditLogoutJob.jobs, :size).by(1)

        job = MHV::AuditLogoutJob.jobs.last
        expect(job['args']).to eq([mhv_correlation_id, signed_in_time.iso8601])
      end
    end

    context 'with already logged out user' do
      let(:user) do
        instance_double(User,
                        uuid: 'user-uuid',
                        mhv_correlation_id:,
                        mhv_last_signed_in: nil)
      end

      it 'does not enqueue job or update user' do
        expect(user).not_to receive(:mhv_last_signed_in=)
        expect(user).not_to receive(:save)

        expect { described_class.logout(user) }.not_to change(MHV::AuditLogoutJob.jobs, :size)
      end
    end
  end

  context 'with delegate user having MHV credentials' do
    let(:mhv_correlation_id) { '12345' }
    let(:user_uuid1) { 'user1-uuid' }
    let(:user_uuid2) { 'user2-uuid' }
    let(:primary_user) do
      instance_double(User,
                      uuid: user_uuid1,
                      mhv_correlation_id:,
                      mhv_last_signed_in: nil,
                      loa3?: true)
    end
    let(:delegate_user) do
      instance_double(User,
                      uuid: user_uuid2,
                      mhv_correlation_id:,
                      mhv_last_signed_in: nil,
                      loa3?: true)
    end

    before do
      allow(primary_user).to receive(:save).and_return(true)
      allow(primary_user).to receive(:mhv_last_signed_in=)
    end

    it 'handles login correctly with delegate users' do
      expect(primary_user).to receive(:mhv_last_signed_in=)
      expect(primary_user).to receive(:save)

      expect { described_class.login(primary_user) }.to change(MHV::AuditLoginJob.jobs, :size).by(1)

      job_args = MHV::AuditLoginJob.jobs.last['args']
      expect(job_args[0]).to eq(mhv_correlation_id)
    end

    it 'handles logout correctly with delegate users' do
      allow(primary_user).to receive(:mhv_last_signed_in).and_return(Time.current)

      expect(primary_user).to receive(:mhv_last_signed_in=).with(nil)
      expect(primary_user).to receive(:save)

      expect { described_class.logout(primary_user) }.to change(MHV::AuditLogoutJob.jobs, :size).by(1)

      job_args = MHV::AuditLogoutJob.jobs.last['args']
      expect(job_args[0]).to eq(mhv_correlation_id)
      expect(job_args[1]).to eq(primary_user.mhv_last_signed_in.iso8601)
    end
  end
end
