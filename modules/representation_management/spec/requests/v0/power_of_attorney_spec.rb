# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PowerOfAttorneyController', type: :request do
  let(:base_path) { '/representation_management/v0/power_of_attorney' }
  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:icn) { '123456789' }
  let(:service) { instance_double(BenefitsClaims::Service) }
  let(:organization) { create(:organization, poa: 'og1') }
  let(:representative) { create(:representative, representative_id: '123', poa_codes: ['rp1']) }

  before do
    allow(controller).to receive(:current_user).and_return(user)
    allow(user).to receive(:icn).and_return(icn)
    allow(BenefitsClaims::Service).to receive(:new).with(icn).and_return(service)
  end

  describe 'GET #index' do
    it 'returns a successful response' do
      allow(service).to receive(:get_power_of_attorney).and_return({ data: { type: 'organization',
                                                                             attributes: { code: 'og1' } } })
      allow(controller).to receive(:find_poa_by_code).and_return(organization)
      get base_path
      expect(response).to be_successful
    end
  end

  describe 'private methods' do
    before do
      allow(service).to receive(:get_power_of_attorney).and_return({ data: { type: 'organization',
                                                                             attributes: { code: 'og1' } } })
    end

    it 'finds poa by code' do
      allow(controller).to receive(:find_organization).and_return(organization)
      expect(controller.send(:find_poa_by_code, 'organization', 'og1')).to eq(organization)
    end

    it 'finds organization' do
      allow(Veteran::Service::Organization).to receive(:find).with('og1').and_return(organization)
      expect(controller.send(:find_organization, 'og1')).to eq(organization)
    end

    it 'finds representative' do
      allow(Veteran::Service::Representative).to receive(:where).with('? = ANY(poa_codes)',
                                                                      'rp1').and_return([representative])
      expect(controller.send(:find_representative, 'rp1')).to eq(representative)
    end

    it 'serializes organization' do
      serialized_org = controller.send(:serialize_organization, organization)
      expect(serialized_org).to be_a(Hash)
      expect(serialized_org[:id]).to eq(organization.id)
    end

    it 'serializes representative' do
      serialized_rep = controller.send(:serialize_representative, representative)
      expect(serialized_rep).to be_a(Hash)
      expect(serialized_rep[:id]).to eq(representative.id)
    end
  end
end
