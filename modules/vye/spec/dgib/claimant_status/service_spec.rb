# frozen_string_literal: true

require 'rails_helper'
require 'dgib/claimant_status/service'

RSpec.describe Vye::DGIB::ClaimantStatus::Service do
  include ActiveSupport::Testing::TimeHelpers

  let(:claimant_id) { 600_010_259 }
  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:service) { described_class.new(user) }
  let(:json_body) { 'modules/vye/spec/fixtures/claimant_response.json' }
  let(:response_body) { JSON.parse(File.read(json_body)) }
  let(:successful_mocked_response) { double('faraday_response', status: 200, body: response_body, ok?: true) }

  describe '#get_verification_record' do
    before do
      allow(service).to receive(:get_claimant_status).with(claimant_id).and_return(successful_mocked_response)
    end

    context 'when successful' do
      it 'returns a status of 200' do
        travel_to Time.zone.local(2022, 2, 9, 12) do
          response = service.get_claimant_status(claimant_id)
          expect(response.status).to eq(200)
          expect(response.ok?).to be(true)
        end
      end
    end
  end
end
