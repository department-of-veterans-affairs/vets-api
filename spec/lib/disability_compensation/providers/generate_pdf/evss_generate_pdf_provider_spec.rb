# frozen_string_literal: true

require 'rails_helper'
require 'disability_compensation/factories/api_provider_factory'
require 'disability_compensation/providers/generate_pdf/evss_generate_pdf_provider'
require 'support/disability_compensation_form/shared_examples/generate_pdf_service_provider'

RSpec.describe EvssGeneratePdfProvider do
  let(:current_user) do
    create(:user)
  end

  let(:auth_headers) do
    EVSS::AuthHeaders.new(current_user).to_h
  end

  before do
    allow(Flipper).to receive(:enabled?).with(ApiProviderFactory::FEATURE_TOGGLE_GENERATE_PDF).and_return(false)
  end

  it_behaves_like 'generate pdf service provider'

  it 'creates a breakered evss service' do
    provider = EvssGeneratePdfProvider.new(auth_headers)
    expect(provider.instance_variable_get(:@service).class).to equal(EVSS::DisabilityCompensationForm::Service)

    provider = EvssGeneratePdfProvider.new(auth_headers, breakered: true)
    expect(provider.instance_variable_get(:@service).class).to equal(EVSS::DisabilityCompensationForm::Service)
  end

  it 'creates a non-breakered evss service' do
    provider = EvssGeneratePdfProvider.new(auth_headers, breakered: false)
    expect(provider.instance_variable_get(:@service).class)
      .to equal(EVSS::DisabilityCompensationForm::NonBreakeredService)
  end

  it 'retrieves a generated 526 pdf from the EVSS API' do
    VCR.use_cassette('form526_backup/200_evss_get_pdf', match_requests_on: %i[uri method]) do
      provider = EvssGeneratePdfProvider.new(auth_headers)
      response = provider.generate_526_pdf({}.to_json)
      expect(response.body['pdf']).to eq('<big long pdf string, but not required here>')
    end
  end
end
