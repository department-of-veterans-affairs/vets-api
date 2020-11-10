# frozen_string_literal: true

require 'rails_helper'
require 'dmc/fsr_service'

RSpec.describe DMC::FSRService do
  describe '#submit_financial_status_report' do
    let(:valid_form_data) { get_fixture('dmc/fsr_submission') }
    let(:malformed_form_data) do
      { 'bad' => 'data' }
    end

    context 'with valid form data' do
      it 'accepts the submission' do
        VCR.use_cassette('dmc/submit_fsr') do
          service = described_class.new
          res = service.submit_financial_status_report(valid_form_data)
          expect(res.status).to eq('Document created successfully and uploaded to File Net.')
        end
      end
    end

    context 'with malformed form' do
      it 'does not accept the submission' do
        VCR.use_cassette('dmc/submit_fsr_error') do
          service = described_class.new
          expect { service.submit_financial_status_report(malformed_form_data) }.to raise_error(
            Common::Exceptions::BackendServiceException
          ) do |e|
            expect(e.message).to match(/DMC400/)
          end
        end
      end
    end
  end
end
