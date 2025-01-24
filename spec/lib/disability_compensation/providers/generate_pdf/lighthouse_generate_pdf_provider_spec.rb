# frozen_string_literal: true

require 'rails_helper'
require 'disability_compensation/factories/api_provider_factory'
require 'disability_compensation/providers/generate_pdf/lighthouse_generate_pdf_provider'
require 'support/disability_compensation_form/shared_examples/generate_pdf_service_provider'
require 'lighthouse/service_exception'

RSpec.describe LighthouseGeneratePdfProvider do
  let(:auth_headers) { {} }

  before do
    @provider = LighthouseGeneratePdfProvider.new(auth_headers)
    allow(Flipper).to receive(:enabled?).with(ApiProviderFactory::FEATURE_TOGGLE_GENERATE_PDF).and_return(true)
  end

  it_behaves_like 'generate pdf service provider'

  # TODO: Implement in Ticket#
  # it 'retrieves a generated 526 pdf from the Lighthouse API' do
  #   VCR.use_cassette('lighthouse/benefits_claims/generate_pdf/200_response') do
  #
  #     response = @provider.generate_526_pdf
  #     expect(response).to eq(nil)
  #   end
  # end
end
