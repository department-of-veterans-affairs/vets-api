# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RepresentationManagement::Form2122Data, type: :model do
  describe 'validations' do
    subject { described_class.new }

    it { expect(subject).to validate_presence_of(:organization_name) }

    describe '#organization_name' do
      let(:form_2122_data) { described_class.new }
      let(:organization_name) { 'Test Organization' }

      before do
        form_2122_data.instance_variable_set(:@organization_name, organization_name)
      end

      context 'when organization is found in AccreditedOrganization' do
        it 'returns the name from AccreditedOrganization' do
          accredited_org = double('AccreditedOrganization', name: 'Accredited Org Name')
          allow(AccreditedOrganization).to receive(:find_by).with(poa: organization_name).and_return(accredited_org)

          expect(form_2122_data.organization_name).to eq('Accredited Org Name')
        end
      end

      context 'when organization is found in Veteran::Service::Organization' do
        it 'returns the name from Veteran::Service::Organization' do
          allow(AccreditedOrganization).to receive(:find_by).with(poa: organization_name).and_return(nil)
          veteran_org = double('Veteran::Service::Organization', name: 'Veteran Org Name')
          allow(Veteran::Service::Organization).to receive(:find_by).with(poa: organization_name).and_return(veteran_org)

          expect(form_2122_data.organization_name).to eq('Veteran Org Name')
        end
      end

      context 'when organization is not found in either' do
        it 'returns the original organization name' do
          allow(AccreditedOrganization).to receive(:find_by).with(poa: organization_name).and_return(nil)
          allow(Veteran::Service::Organization).to receive(:find_by).with(poa: organization_name).and_return(nil)

          expect(form_2122_data.organization_name).to eq(organization_name)
        end
      end
    end
  end
end
