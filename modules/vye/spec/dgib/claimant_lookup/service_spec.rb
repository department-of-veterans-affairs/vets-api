# frozen_string_literal: true

require 'rails_helper'
require 'dgib/claimant_lookup/service'

RSpec.describe Vye::DGIB::ClaimantLookup::Service do
  include ActiveSupport::Testing::TimeHelpers

  let(:ssn) { '123-45-6789' }
  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:service) { Vye::DGIB::ClaimantLookup::Service.new(user) }
  let(:json_body) { 'modules/vye/spec/fixtures/claimant_lookup_response.json' }
  let(:response_body) { JSON.parse(File.read(json_body)) }
  let(:successful_mocked_response) { double('faraday_response', status: 200, body: response_body, ok?: true) }

  describe '#claimant_lookup' do
    before do
      allow(service).to receive(:claimant_lookup).with(ssn).and_return(successful_mocked_response)
    end

    context 'when successful' do
      it 'returns a status of 200' do
        travel_to Time.zone.local(2022, 2, 9, 12) do
          response = service.claimant_lookup(ssn)

          expect(response.status).to eq(200)
          expect(response.ok?).to be(true)
        end
      end
    end
  end
end
