# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RepresentationManagement::V0::PowerOfAttorneyController, type: :controller do
  before do
    @routes = RepresentationManagement::Engine.routes
  end

  context 'with a signed in user' do
    let(:user) { create(:user, :loa3) }
    let(:icn) { '123498767V234859' }
    let(:service) { instance_double(BenefitsClaims::Service) }
    let(:org_poa) { 'og1' }
    let(:rep_poa) { 'rp1' }
    let(:organization) { create(:organization, poa: org_poa) }
    let(:representative) { create(:representative, representative_id: '123', poa_codes: [rep_poa]) }

    before do
      sign_in_as(user)

      allow_any_instance_of(BenefitsClaims::Configuration).to receive(:access_token).and_return('fake_access_token')
      allow(controller).to receive(:current_user).and_return(user)
      allow(user).to receive(:icn).and_return(icn)
      allow(BenefitsClaims::Service).to receive(:new).with(icn).and_return(service)
    end

    describe 'GET #index' do
      it 'returns a successful response' do
        allow(service).to receive(:get_power_of_attorney).and_return({ 'data' => { 'type' => 'organization',
                                                                                   'attributes' => { 'code' => org_poa } } }) # rubocop:disable Layout/LineLength
        allow(controller).to receive(:get_poa).and_return(organization)
        get :index

        expect(response).to be_successful
      end

      it 'returns the expected response when a user has an org POA' do
        expected_serialized_organization = ActiveModelSerializers::SerializableResource.new(
          organization,
          serializer: RepresentationManagement::PowerOfAttorney::OrganizationSerializer
        ).to_json
        allow(service).to receive(:get_power_of_attorney).and_return({ 'data' => { 'type' => 'organization',
                                                                                   'attributes' => { 'code' => org_poa } } }) # rubocop:disable Layout/LineLength
        allow(controller).to receive(:get_poa).and_return(organization)
        get :index

        expect(response.body).to eq(expected_serialized_organization)
      end

      it 'returns the expected response when a user has a rep POA' do
        expected_serialized_representative = ActiveModelSerializers::SerializableResource.new(
          representative,
          serializer: RepresentationManagement::PowerOfAttorney::RepresentativeSerializer
        ).to_json
        allow(service).to receive(:get_power_of_attorney).and_return({ 'data' => { 'type' => 'individual',
                                                                                   'attributes' => { 'code' => rep_poa } } }) # rubocop:disable Layout/LineLength
        allow(controller).to receive(:get_poa).and_return(representative)
        get :index

        expect(response.body).to eq(expected_serialized_representative)
      end

      it 'returns the expected response when a user does not has a POA' do
        allow(service).to receive(:get_power_of_attorney).and_return({})
        get :index

        expect(response.body).to eq("{}") # rubocop:disable Style/StringLiterals
      end
    end
  end

  context 'without a signed in user' do
    describe 'GET #index' do
      it 'returns a 401/unauthorized status' do
        get :index

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
