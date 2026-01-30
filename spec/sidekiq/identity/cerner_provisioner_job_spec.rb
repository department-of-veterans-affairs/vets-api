# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Identity::CernerProvisionerJob, type: :job do
  subject(:job) { described_class.new }

  let(:icn) { '123456789' }
  let(:source) { :some_source }
  let(:cerner_provisioner) { instance_double(Identity::CernerProvisioner) }

  before do
    allow(Identity::CernerProvisioner).to receive(:new).and_return(cerner_provisioner)
    allow(cerner_provisioner).to receive(:perform)
  end

  it 'is unique for 5 minutes' do
    expect(described_class.sidekiq_options['unique_for']).to eq(5.minutes)
  end

  it 'does not retry' do
    expect(described_class.sidekiq_options['retry']).to be(false)
  end

  describe '.sidekiq_unique_context' do
    let(:icn) { '123456789' }
    let(:sidekiq_job1) { { 'class' => described_class.name, 'queue' => 'default', 'args' => [icn, :foo] } }
    let(:sidekiq_job2) { { 'class' => described_class.name, 'queue' => 'default', 'args' => [icn, :bar] } }

    it 'treats jobs with same ICN but different source as having the same uniqueness key' do
      job_key1 = described_class.sidekiq_unique_context(sidekiq_job1)
      job_key2 = described_class.sidekiq_unique_context(sidekiq_job2)
      expect(job_key1).to eq(job_key2)
      expect(job_key1).to eq([described_class.name, 'default', [icn]])
    end

    context 'when a job is already enqueued for the same ICN' do
      around do |example|
        Sidekiq::Enterprise.unique!
        example.run
      end

      it 'does not run an inline job' do
        described_class.perform_async(icn, :foo)
        described_class.perform_inline(icn, :bar)
        expect(cerner_provisioner).not_to have_received(:perform)
      end
    end
  end

  describe '#perform' do
    it 'calls the CernerProvisioner service class' do
      expect(cerner_provisioner).to receive(:perform)
      job.perform(icn, source)
    end

    context 'when an error occurs' do
      let(:error_message) { 'Some error occurred' }

      before do
        allow(cerner_provisioner).to receive(:perform).and_raise(Identity::Errors::CernerProvisionerError,
                                                                 error_message)
        allow(Rails.logger).to receive(:error)
      end

      it 'logs the error message' do
        expect(Rails.logger).to receive(:error).with('[Identity] [CernerProvisionerJob] error',
                                                     { icn:, error_message:, source: })
        job.perform(icn, source)
      end

      context 'when source is :tou' do
        let(:source) { :tou }

        it 'raises the error' do
          expect { job.perform(icn, source) }.to raise_error(Identity::Errors::CernerProvisionerError, error_message)
        end
      end

      context 'when source is not :tou' do
        let(:source) { :sis }

        it 'does not raise the error' do
          expect { job.perform(icn, source) }.not_to raise_error
        end
      end

      context 'when source is nil' do
        let(:source) { nil }

        it 'does not raise the error' do
          expect { job.perform(icn, source) }.not_to raise_error
        end
      end
    end
  end
end
