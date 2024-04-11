# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TermsOfUse::Provisioner do
  subject(:provisioner) { described_class.new(icn:, first_name:, last_name:, mpi_gcids:) }

  let(:icn) { '123456789' }
  let(:first_name) { 'John' }
  let(:last_name) { 'Doe' }
  let(:mpi_gcids) do
    ['1012667145V762142^NI^200M^USVHA^P',
     '1005490754^NI^200DOD^USDOD^A',
     '600043201^PI^200CORP^USVBA^A',
     '123456^PI^200ESR^USVHA^A',
     '123456^PI^648^USVHA^A',
     '123456^PI^200BRLS^USVBA^A']
  end

  describe 'validations' do
    context 'when all attributes are present' do
      it 'is valid with all attributes' do
        expect(provisioner).to be_valid
      end
    end

    context 'when icn is missing' do
      let(:icn) { nil }

      it 'is not valid' do
        expect { provisioner }.to raise_error(TermsOfUse::Errors::ProvisionerError)
          .with_message('Validation failed: Icn can\'t be blank')
      end
    end

    context 'when first_name is missing' do
      let(:first_name) { nil }

      it 'is not valid' do
        expect { provisioner }.to raise_error(TermsOfUse::Errors::ProvisionerError)
          .with_message('Validation failed: First name can\'t be blank')
      end
    end

    context 'when last_name is missing' do
      let(:last_name) { nil }

      it 'is not valid' do
        expect { provisioner }.to raise_error(TermsOfUse::Errors::ProvisionerError)
          .with_message('Validation failed: Last name can\'t be blank')
      end
    end

    context 'when mpi_gcids is missing' do
      let(:mpi_gcids) { nil }

      it 'is not valid' do
        expect { provisioner }.to raise_error(TermsOfUse::Errors::ProvisionerError)
          .with_message('Validation failed: MPI gcids can\'t be blank')
      end
    end
  end

  describe '#perform' do
    let(:service) { instance_double(MAP::SignUp::Service) }

    before do
      allow(MAP::SignUp::Service).to receive(:new).and_return(service)
    end

    context 'when agreement is signed' do
      before do
        allow(service).to receive(:update_provisioning).and_return({ agreement_signed: true })
      end

      it 'returns true' do
        expect(provisioner.perform).to eq(true)
      end
    end

    context 'when agreement is not signed' do
      let(:expected_log) { '[TermsOfUse] [Provisioner] update_provisioning error' }
      let(:service_response) { { agreement_signed: false } }

      before do
        allow(Rails.logger).to receive(:error)
        allow(service).to receive(:update_provisioning).and_return(service_response)
      end

      it 'raises and logs an error' do
        expect { provisioner.perform }.to raise_error(TermsOfUse::Errors::ProvisionerError)
        expect(Rails.logger).to have_received(:error).with(expected_log, { icn:, response: service_response })
      end
    end

    context 'when a client error is raised' do
      let(:expected_log) { "[TermsOfUse] [Provisioner] Error: #{expected_error_message}" }
      let(:expected_error_message) { 'Failed to provision' }

      before do
        allow(service).to receive(:update_provisioning)
          .and_raise(Common::Client::Errors::ClientError.new(expected_error_message))
      end

      it 'logs the error and raises a ProvisionerError' do
        expect(Rails.logger).to receive(:error).with(expected_log, { icn: })
        expect { provisioner.perform }.to raise_error(TermsOfUse::Errors::ProvisionerError)
      end
    end
  end
end
