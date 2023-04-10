# frozen_string_literal: true

require 'rails_helper'
require 'mockdata/mpi/find'

RSpec.describe MockedAuthentication::Mockdata::MPI::Find do
  subject { described_class.new(icn:) }

  let(:time) { Time.zone.now }
  let(:icn) { '1234567890' }

  describe '#perform' do
    let(:mpi_response) { double('MPI response', body: expected_response_body) }
    let(:expected_response_body) { '<xml> </xml>' }
    let(:expected_response_yml) do
      <<~YAML
        ---
        :method: :post
        :body: "#{expected_response_body}"
        :headers:
          :connection: close
          :date: #{time.strftime('%a, %d %b %Y %H:%M:%S %Z')}
          content-type: text/xml
        :status: 200
      YAML
    end

    before do
      Timecop.freeze(time)
      http = double
      allow(Net::HTTP).to receive(:start).and_yield http
      allow(http).to receive(:request).with(an_instance_of(Net::HTTP::Post)).and_return(mpi_response)
    end

    after { Timecop.return }

    context 'when the icn is valid' do
      it 'returns the expected yml' do
        expect(subject.perform).to eq(expected_response_yml)
      end
    end

    context 'when the icn is invalid' do
      let(:expected_response_body) { '<xml> <code code=\"INTERR\"> </xml>' }

      it 'raises a RecordNotFound error' do
        expect { subject.perform }.to raise_error(Common::Exceptions::RecordNotFound)
      end
    end
  end
end
