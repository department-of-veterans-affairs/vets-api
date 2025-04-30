# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Identity::CernerProvisioner do
  subject(:provisioner) { described_class.new(icn:) }

  let(:icn) { '123456789' }
  let(:first_name) { 'John' }
  let(:last_name) { 'Doe' }

  describe 'validations' do
    context 'when all attributes are present' do
      it 'is valid with all attributes' do
        expect(provisioner).to be_valid
      end
    end

    context 'when icn is missing' do
      let(:icn) { nil }

      it 'is not valid' do
        expect { provisioner }.to raise_error(Identity::Errors::CernerProvisionerError)
          .with_message('Validation failed: Icn can\'t be blank')
      end
    end
  end

  describe '#perform' do
    let(:service) { instance_double(MAP::SignUp::Service) }
    let(:find_profile_response) { create(:find_profile_response, profile: mpi_profile) }
    let(:mpi_profile) do
      build(:mpi_profile,
            icn:,
            given_names: [first_name],
            family_name: last_name)
    end

    before do
      allow(MAP::SignUp::Service).to receive(:new).and_return(service)
      allow_any_instance_of(MPI::Service).to receive(:find_profile_by_identifier).and_return(find_profile_response)
    end

    context 'when agreement is signed' do
      let(:agreement_signed) { true }
      let(:cerner_provisioned) { true }

      before do
        allow(service).to receive(:update_provisioning).and_return({ agreement_signed:, cerner_provisioned: })
      end

      context 'and account is not cerner provisionable' do
        let(:cerner_provisioned) { false }
        let(:expected_log) { '[Identity] [CernerProvisioner] update_provisioning error' }
        let(:service_response) { { agreement_signed:, cerner_provisioned: } }

        before { allow(Rails.logger).to receive(:error) }

        it 'raises and logs an error' do
          expect { provisioner.perform }.to raise_error(Identity::Errors::CernerProvisionerError)
          expect(Rails.logger).to have_received(:error).with(expected_log, { icn:, response: service_response })
        end
      end

      context 'and account is cerner provisionable' do
        let(:cerner_provisioned) { true }

        it 'does not return error' do
          expect { provisioner.perform }.not_to raise_error
        end
      end
    end

    context 'when agreement is not signed' do
      let(:expected_log) { '[Identity] [CernerProvisioner] update_provisioning error' }
      let(:service_response) { { agreement_signed: false } }

      before do
        allow(Rails.logger).to receive(:error)
        allow(service).to receive(:update_provisioning).and_return(service_response)
      end

      it 'raises and logs an error' do
        expect { provisioner.perform }.to raise_error(Identity::Errors::CernerProvisionerError)
        expect(Rails.logger).to have_received(:error).with(expected_log, { icn:, response: service_response })
      end
    end

    context 'when a client error is raised' do
      let(:expected_log) { "[Identity] [CernerProvisioner] Error: #{expected_error_message}" }
      let(:expected_error_message) { 'Failed to provision' }

      before do
        allow(service).to receive(:update_provisioning)
          .and_raise(Common::Client::Errors::ClientError.new(expected_error_message))
      end

      it 'logs the error and raises a ProvisionerError' do
        expect(Rails.logger).to receive(:error).with(expected_log, { icn: })
        expect { provisioner.perform }.to raise_error(Identity::Errors::CernerProvisionerError)
      end
    end
  end
end
