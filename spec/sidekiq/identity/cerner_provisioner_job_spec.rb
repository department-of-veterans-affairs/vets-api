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
    end
  end
end
