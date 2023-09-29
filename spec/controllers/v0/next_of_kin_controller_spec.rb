# frozen_string_literal: true

require 'rails_helper'
require 'va_profile/health_benefit/service'
require 'va_profile/health_benefit/associated_persons_response'

RSpec.describe V0::NextOfKinController, type: :controller do
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
          expect(el['attributes']['contact_type']).to match(/next of kin/i)
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
        next_of_kin: {
          contact_type: 'Primary Next of Kin',
          given_name: 'Jonnie',
          family_name: 'Shaye',
          relationship: 'Son/Daughter',
          address_line1: '123 Main St.',
          city: 'Baltimore',
          state: 'MD',
          zip_code: '21205',
          primary_phone: '111-222-3333'
        }
      }
    end

    context 'successful request' do
      let(:service_status) { 200 }
      let(:fixture_path) { %w[spec fixtures va_profile health_benefit_v1_messages.json] }

      before do
        allow_any_instance_of(VAProfile::HealthBenefit::Service)
          .to receive(:post_next_of_kin).and_return(response_object)
      end

      it 'creates a next-of-kin record' do
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
        params[:next_of_kin][:primary_phone] = ''
        post(:create, params:)
        expect(response).to have_http_status(:unprocessable_entity)
        expect(json['errors']).not_to be_empty
      end
    end
  end
end
