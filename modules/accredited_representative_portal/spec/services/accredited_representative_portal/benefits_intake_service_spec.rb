# frozen_string_literal: true

require 'rails_helper'
require 'accredited_representative_portal/benefits_intake_service'
require 'benefits_intake_service/service'

RSpec.describe AccreditedRepresentativePortal::BenefitsIntakeService do
  describe '.base_request_headers' do
    context 'missing api key' do
      before do
        Settings.accredited_representative_portal.lighthouse.benefits_intake.api_key = nil
      end

      it 'raises an error' do
        expect do
          described_class.configuration.base_request_headers
        end.to raise_error 'No api_key set for benefits_intake. ' \
                           "Please set 'accredited_representative_portal.lighthouse.benefits_intake.api_key'"
      end
    end

    context 'present api key' do
      before do
        Settings.accredited_representative_portal.lighthouse.benefits_intake.api_key = 'test_api_key'
      end

      it 'has the apikey present in the configuration' do
        expect(described_class.configuration.base_request_headers['apikey']).to eq 'test_api_key'
      end
    end
  end
end
