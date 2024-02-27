# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/benefits_education/service'
require 'lighthouse/benefits_education/outside_working_hours'

RSpec.describe V1::Post911GIBillStatusesController, type: :controller do
    include SchemaMatchers

#   let(:user) { FactoryBot.create(:user, :loa3) }
  let(:user) { FactoryBot.create(:user, :loa3, icn: '1000000000V100000') }
#   let(:user) { FactoryBot.create(:user, :loa3, icn: '1012667145V762142') }
  before { sign_in_as(user) }

  let(:once) { { times: 1, value: 1 } }

  let(:tz) { ActiveSupport::TimeZone.new(::BenefitsEducation::Service::OPERATING_ZONE) }
  let(:noon) { tz.parse('1st Feb 2018 12:00:00') }

  context 'inside working hours' do
    before do
        allow(::BenefitsEducation::Service).to receive(:within_scheduled_uptime?).and_return(true)
    end

    it 'returns a 404 when vet isn\'t found' do
        VCR.use_cassette('lighthouse/benefits_education/gi_bill_status/vet_not_found') do
            resp = get :show
            expect(response.status).to eq(404)
            json_response = JSON.parse(response.body)
            expect(json_response['error']['title']).to eq('Not Found')
            expect(json_response['error']['detail']).to eq('Icn not found.')
        end
    end
  end
end
