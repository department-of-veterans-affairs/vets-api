# frozen_string_literal: true

require 'rails_helper'

describe Vet360::ReferenceData::Service, skip_vet360: true do
  subject { described_class.new }

  before { Timecop.freeze('2018-04-09T17:52:03Z') }

  after  { Timecop.return }

  %w[countries states zipcodes].each do |message|
    describe "##{message}" do
      let(:cassette) { "vet360/reference_data/#{message}" }

      context 'when successful' do
        it 'returns a status of 200', :aggregate_failures do
          VCR.use_cassette(cassette, VCR::MATCH_EVERYTHING) do
            response = subject.send(message)

            expect(response).to be_ok
            expect(response.send(message)).to be_a(Array)
          end
        end

        it 'returns the correct data' do
          VCR.use_cassette(cassette, VCR::MATCH_EVERYTHING) do
            response = subject.send(message)
            data = response.send(message).first

            case message
            when 'countries'
              expect(data).to have_key('country_name')
              expect(data).to have_key('country_code_iso3')
            when 'states'
              expect(data).to have_key('state_name')
              expect(data).to have_key('state_code')
            when 'zipcodes'
              expect(data).to have_key('zip_code')
            end
          end
        end
      end
    end
  end
end
