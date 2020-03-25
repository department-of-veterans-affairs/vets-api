# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Facilities::DrivetimeBands::Client do
  RSpec::Matchers.define :has_offset_and_limit do |offset, limit|
    match do |params|
      params[:resultRecordCount].eql?(limit) && params[:resultOffset].eql?(offset)
    end
  end

  let(:faraday_response_offset_0) { double(Faraday::Response.new) }
  let(:faraday_response_offset_10) { double(Faraday::Response.new) }

  describe 'get_drivetime_bands' do
    subject { described_class.new }

    before do
      allow_any_instance_of(
        Faraday::Connection
      ).to receive(:get).with(anything, has_offset_and_limit(0, 10)).and_return(faraday_response_offset_0)

      allow_any_instance_of(
        Faraday::Connection
      ).to receive(:get).with(anything, has_offset_and_limit(10, 10)).and_return(faraday_response_offset_10)
    end

    it 'uses offset and limit' do
      allow(faraday_response_offset_0).to receive(:env).and_return(double(body: { features: [*1..10] }.to_json))
      allow(faraday_response_offset_10).to receive(:env).and_return(double(body: { features: [*1..4] }.to_json))

      first_response = subject.get_drivetime_bands(0, 10)
      expect(first_response.length).to be(10)

      second_response = subject.get_drivetime_bands(10, 10)
      expect(second_response.length).to be(4)
    end
  end

  describe 'error handling' do
    subject { described_class.new }

    let(:faraday_error_response) { double(Faraday::Response.new) }

    before do
      allow_any_instance_of(
        Faraday::Connection
      ).to receive(:get).with(anything, has_offset_and_limit(0, 10)).and_return(faraday_error_response)
    end

    it 'raises PSSGDownload error when error is present in the body' do
      allow(faraday_error_response).to receive(:env).and_return(double(body: { error: 'Error in download' }.to_json))

      expect do
        subject.get_drivetime_bands(0, 10)
      end.to raise_error Facilities::DrivetimeBands::DownloadError
    end
  end
end
