# frozen_string_literal: true

require 'rails_helper'
require 'va_profile/health_benefit/service'
require 'va_profile/health_benefit/associated_persons_response'

RSpec.describe V0::EmergencyContactsController, type: :controller do
  let(:user) { build(:user, :loa3) }
  let(:service_body) { Rails.root.join(*fixture_path).read }
  let(:service_response) { OpenStruct.new(status: service_status, body: service_body) }
  let(:response_object) { VAProfile::HealthBenefit::AssociatedPersonsResponse.from(service_response) }
  let(:json) { JSON.parse(response.body) }

  describe '#index' do
    context 'successful request' do
      let(:service_status) { 200 }
      let(:fixture_path) { %w[spec fixtures va_profile health_benefit_v1_read_ap.json] }

      before do
        allow_any_instance_of(VAProfile::HealthBenefit::Service)
          .to receive(:get_associated_persons).and_return(response_object)
      end

      it 'returns emergency contacts' do
        sign_in_as user
        get :index
        expect(response).to have_http_status(:success)
        expect(json['data'].length).to eq(1)
        json['data'].each do |el|
          expect(el['attributes']['contact_type']).to match(/emergency contact/i)
        end
      end
    end

    context 'user is not authenticated' do
      it 'returns an unauthorized status code' do
        get :index
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe '#create' do
    let(:params) do
      {
        emergency_contact: {
          contact_type: 'Emergency Contact',
          given_name: 'Jonnie',
          family_name: 'Shaye',
          primary_phone: '111-222-3333'
        }
      }
    end

    context 'successful request' do
      let(:service_status) { 200 }
      let(:fixture_path) { %w[spec fixtures va_profile health_benefit_v1_messages.json] }

      before do
        allow_any_instance_of(VAProfile::HealthBenefit::Service)
          .to receive(:post_emergency_contacts).and_return(response_object)
      end

      it 'creates an emergency contact' do
        sign_in_as user
        post(:create, params:)
        expect(response).to have_http_status(:success)
      end
    end

    context 'user is not authenticated' do
      it 'returns an unauthorized status code' do
        post(:create, params:)
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'invalid data' do
      it 'returns validation errors' do
        sign_in_as user
        params[:emergency_contact][:primary_phone] = ''
        post(:create, params:)
        expect(response).to have_http_status(:unprocessable_entity)
        expect(json['errors']).not_to be_empty
      end
    end
  end
end
