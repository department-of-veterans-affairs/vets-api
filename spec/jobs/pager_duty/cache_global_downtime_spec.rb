# frozen_string_literal: true

require 'rails_helper'
require 'pager_duty/cache_global_downtime'

RSpec.describe PagerDuty::CacheGlobalDowntime, type: %i[job aws_helpers] do
  let(:subject) { described_class.new }

  let(:client_stub) { instance_double('PagerDuty::MaintenanceClient') }
  let(:mw_hash) { FactoryBot.build(:maintenance_hash) }

  before do
    allow(Settings.maintenance).to receive(:services).and_return({ global: 'ABCDEF' })
    allow(Settings.maintenance.aws).to receive(:access_key_id).and_return('key')
    allow(Settings.maintenance.aws).to receive(:secret_access_key).and_return('secret')
    allow(Settings.maintenance.aws).to receive(:bucket).and_return('bucket')
    allow(Settings.maintenance.aws).to receive(:region).and_return('region')
    allow(PagerDuty::MaintenanceClient).to receive(:new) { client_stub }
  end

  describe '#perform' do
    context 'with success response from client' do
      let(:filename) { 'tmp/maintenance_windows.json' }
      let(:options) { { 'service_ids' => %w[ABCDEF] } }

      before { stub_maintenance_windows_s3(filename) }

      after { File.delete(filename) }

      it 'uploads an empty list of global downtimes' do
        allow(client_stub).to receive(:get_all).with(options).and_return([])
        subject.perform
        expect(File.read(filename)).to eq('[]')
      end

      it 'uploads a populated list of global downtimes' do
        allow(client_stub).to receive(:get_all).with(options).and_return([mw_hash])
        subject.perform
        expect(File.read(filename)).to eq("[#{mw_hash.to_json}]")
      end
    end

    context 'with error response from client' do
      before do
        allow(Settings.sentry).to receive(:dsn).and_return('asdf')
      end

      it 'bails on backend error' do
        expect(client_stub).to receive(:get_all).and_raise(Common::Exceptions::BackendServiceException)
        expect(Raven).to receive(:capture_exception).with(Common::Exceptions::BackendServiceException, level: 'error')

        subject.perform
      end

      it 'bails on client error' do
        expect(client_stub).to receive(:get_all).and_raise(Common::Client::Errors::ClientError)
        expect(Raven).to receive(:capture_exception).with(Common::Client::Errors::ClientError, level: 'error')

        subject.perform
      end
    end
  end
end
