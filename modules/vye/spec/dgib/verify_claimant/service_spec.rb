# frozen_string_literal: true

require 'rails_helper'
require 'dgib/verify_claimant/service'

RSpec.describe Vye::DGIB::VerifyClaimant::Service do
  include ActiveSupport::Testing::TimeHelpers

  let(:claimant_id) { 600_010_259 }
  let(:verified_period_begin_date) { Date.new(2022, 2, 9) }
  let(:verified_period_end_date) { Date.new(2022, 3, 9) }
  let(:verified_through_date) { Date.new(2022, 4, 9) }
  let(:verification_method) { 'VYE' }
  let(:response_type) { 'Y' }

  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:service) { Vye::DGIB::VerifyClaimant::Service.new(user) }
  let(:json_body) { 'modules/vye/spec/fixtures/verify_claimant_response.json' }
  let(:response_body) { JSON.parse(File.read(json_body)) }
  let(:successful_mocked_response) { double('faraday_response', status: 200, body: response_body, ok?: true) }

  describe '#get_verification_record' do
    before do
      allow(service).to receive(:verify_claimant)
        .with(
          claimant_id,
          verified_period_begin_date,
          verified_period_end_date,
          verified_through_date,
          verification_method,
          response_type
        )
        .and_return(successful_mocked_response)
    end

    context 'when successful' do
      it 'returns a status of 200' do
        travel_to Time.zone.local(2022, 2, 9, 12) do
          response = service
                     .verify_claimant(claimant_id,
                                      verified_period_begin_date,
                                      verified_period_end_date,
                                      verified_through_date,
                                      verification_method,
                                      response_type)

          expect(response.status).to eq(200)
          expect(response.ok?).to be(true)
        end
      end
    end
  end
end
