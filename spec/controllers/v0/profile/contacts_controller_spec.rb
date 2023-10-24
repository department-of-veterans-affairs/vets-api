# frozen_string_literal: true

require 'rails_helper'
require 'va_profile/health_benefit/service'
require 'va_profile/health_benefit/associated_persons_response'

RSpec.describe V0::Profile::ContactsController, type: :controller do
  let(:user) { build(:user, :loa3) }
  let(:loa1_user) { build(:user, :loa1) }
  let(:fixture_path) { %w[spec fixtures va_profile health_benefit_v1_associated_persons.json] }
  let(:service_body) { Rails.root.join(*fixture_path).read }
  let(:service_response) { OpenStruct.new(status: 200, body: service_body) }
  let(:response_object) { VAProfile::HealthBenefit::AssociatedPersonsResponse.from(service_response) }
  let(:json) { JSON.parse(subject.body) }

  describe '/v0/profile/contacts' do
    subject { get :index }

    before do
      # mock service response
      allow_any_instance_of(VAProfile::HealthBenefit::Service)
        .to receive(:get_associated_persons).and_return(response_object)

      Flipper.enable(:profile_contacts)
    end

    context 'successful request' do
      it 'returns emergency contacts' do
        sign_in_as user
        expect(subject).to have_http_status(:success)
        expect(json['data'].length).to eq(2)
      end
    end

    context 'user is not authenticated' do
      it 'returns an unauthorized status code' do
        expect(subject).to have_http_status(:unauthorized)
      end
    end

    context 'user is not loa3' do
      it 'returns a forbidden status code' do
        sign_in_as loa1_user
        expect(subject).to have_http_status(:forbidden)
      end
    end

    context 'feature is disabled' do
      it 'returns an unauthorized status code' do
        Flipper.disable(:profile_contacts)
        sign_in_as user
        expect(subject).to have_http_status(:not_found)
      end
    end
  end
end
