# frozen_string_literal: true

require 'rails_helper'
require 'va_profile/health_benefit/service'
require 'va_profile/health_benefit/associated_persons_response'

RSpec.describe V0::EmergencyContactsController, type: :controller do
  let(:user) { build(:user, :loa3) }
  let(:fixture_path) { %w[spec fixtures va_profile health_benefit_v1_read_ap.json] }
  let(:response_body) { Rails.root.join(*fixture_path).read }
  let(:json) { JSON.parse(response.body) }

  before do
    raw_response = OpenStruct.new(status: 200, body: response_body)
    response_object = VAProfile::HealthBenefit::AssociatedPersonsResponse.from(raw_response)
    allow_any_instance_of(VAProfile::HealthBenefit::Service)
      .to receive(:get_associated_persons).and_return(response_object)
    sign_in_as user
  end

  describe 'index' do
    it 'returns emergency contacts' do
      get :index
      pp json
      expect(response).to have_http_status(:success)
      expect(json['data'].length).to eq(2)
      expect(json['data'].first['attributes']['contact_type']).to match(/emergency contact/i)
    end
  end
end
