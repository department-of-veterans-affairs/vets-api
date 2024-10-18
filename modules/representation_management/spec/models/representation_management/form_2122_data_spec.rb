# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RepresentationManagement::Form2122Data, type: :model do
  describe '#organization_name' do
    context 'when organization is found in AccreditedOrganization' do
      it 'returns the name from AccreditedOrganization' do
        accredited_organization = create(:accredited_organization, name: 'Accredited Org Name')
        form_2122_data = described_class.new(organization_id: accredited_organization.id)

        expect(form_2122_data.organization_name).to eq('Accredited Org Name')
      end
    end

    context 'when organization is found in Veteran::Service::Organization' do
      it 'returns the name from Veteran::Service::Organization' do
        veteran_org = create(:organization, name: 'Veteran Org Name')
        form_2122_data = described_class.new(organization_id: veteran_org.poa)

        expect(form_2122_data.organization_name).to eq('Veteran Org Name')
      end
    end

    context 'when organization is not found in either' do
      it 'returns nil' do
        form_2122_data = described_class.new(organization_id: 'Nonexistent Org')

        expect(form_2122_data.organization_name).to eq(nil)
      end
    end
  end
end
