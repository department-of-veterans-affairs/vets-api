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
    let(:organization) { create(:organization, poa: 'og1') }
    let(:representative) { create(:representative, representative_id: '123', poa_codes: ['rp1']) }

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
                                                                                   'attributes' => { 'code' => 'og1' } } }) # rubocop:disable Layout/LineLength
        allow(controller).to receive(:find_poa_by_code).and_return(organization)
        get :index

        expect(response).to be_successful
      end

      it 'returns the expected response when a user has a POA' do
        expected_serialized_organization = ActiveModelSerializers::SerializableResource.new(
          organization,
          serializer: RepresentationManagement::PowerOfAttorney::OrganizationSerializer
        ).to_json
        allow(service).to receive(:get_power_of_attorney).and_return({ 'data' => { 'type' => 'organization',
                                                                                   'attributes' => { 'code' => 'og1' } } }) # rubocop:disable Layout/LineLength
        allow(controller).to receive(:find_poa_by_code).and_return(expected_serialized_organization)
        get :index

        expect(response.body).to eq(expected_serialized_organization)
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
