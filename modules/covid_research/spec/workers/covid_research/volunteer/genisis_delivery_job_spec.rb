# frozen_string_literal: true

require 'rails_helper'
require CovidResearch::Engine.root.join('spec', 'rails_helper.rb')
require_relative '../../../../app/workers/covid_research/volunteer/genisis_delivery_job'
require_relative '../../../../lib/redis_format'

RSpec.describe CovidResearch::Volunteer::GenisisDeliveryJob do
  subject               { described_class.new }

  let(:fmt_double)      { double('RedisFormat Instance', from_redis: submission) }
  let(:form_data)       { read_fixture('encrypted-form.json') }
  let(:response_double) { double('response') }
  let(:service_double)  { double('Service Instance', deliver_form: true) }
  let(:submission)      { read_fixture('valid-update-submission.json') }

  before do
    allow(CovidResearch::RedisFormat).to receive(:new).and_return(fmt_double)
    allow(CovidResearch::Volunteer::GenisisService).to receive(:new).and_return(service_double)
  end

  describe '#perform' do
    before do
      allow(service_double).to receive(:delivery_response).and_return(response_double)
      allow(response_double).to receive(:success?).and_return(true)
    end

    it 'converts the raw data to the internal RedisFormat' do
      expect(fmt_double).to receive(:from_redis).with(form_data)

      subject.perform(form_data)
    end

    it 'delivers the form' do
      expect(service_double).to receive(:deliver_form)

      subject.perform(form_data)
    end

    describe 'response handling' do
      it 'does not raise an exception if the response is a success' do
        expect { subject.perform(form_data) }.not_to raise_error
      end

      it 'raises GenisisDeliveryFailure if there is an error' do
        allow(response_double).to receive(:success?).and_return(false)
        allow(response_double).to receive(:body).and_return('Internal Server Error')
        allow(response_double).to receive(:status).and_return(500)

        expect { subject.perform(form_data) }.to raise_error(CovidResearch::Volunteer::GenisisDeliveryFailure)
      end
    end
  end
end
