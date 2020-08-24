# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../../app/services/covid_research/volunteer/genisis_service.rb'
require_relative '../../../covid_research_spec_helper.rb'

RSpec.configure do |c|
  c.include CovidResearchSpecHelper
end

RSpec.describe CovidResearch::Volunteer::GenisisService do
  let(:subject)    { described_class.new(form_data, serializer) }
  let(:serializer) { double('serializer', serialize: 'form') }
  let(:form_data)  { 'form_data' }

  describe 'prep' do
    it 'serializes the data to build the genISIS payload' do
      expect(serializer).to receive(:serialize).with(form_data)

      subject.payload
    end
  end

  describe 'delivery' do
    it 'stores the delivery response' do
      stub_request(:post, "#{Settings.genisis.base_url}#{Settings.genisis.service_path}/formdata")
        .to_return(status: 200, body: '{}')

      subject.deliver_form
      expect(subject.delivery_response).not_to eq(:unattempted)
    end

    it 'increments the form delivery statsd counter' do
      stub_request(:post, "#{Settings.genisis.base_url}#{Settings.genisis.service_path}/formdata")
        .to_return(status: 200, body: '{}')

      expect { subject.deliver_form }.to trigger_statsd_increment(
        'api.covid-research.volunteer.deliver_form.total', times: 1, value: 1
      )
    end

    it 'increments the failed delivery counter if there is an error' do
      stub_request(:post, "#{Settings.genisis.base_url}#{Settings.genisis.service_path}/formdata")
        .to_return(status: 500)

      expect { subject.deliver_form }.to trigger_statsd_increment(
        'api.covid-research.volunteer.deliver_form.fail', times: 1, value: 1
      )
    end
  end
end
