# frozen_string_literal: true

require 'rails_helper'
require 'disability_compensation/factories/api_provider_factory'
require 'disability_compensation/providers/generate_pdf/lighthouse_generate_pdf_provider'
require 'support/disability_compensation_form/shared_examples/generate_pdf_service_provider'
require 'lighthouse/service_exception'

RSpec.describe LighthouseGeneratePdfProvider do
  let(:auth_headers) do
    EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h)
  end
  let(:user) { create(:user, :loa3) }
  let(:saved_claim) { create(:va526ez) }
  let(:user_account) { create(:user_account, icn: '123498767V234859') }

  let(:submission) do
    create(:form526_submission,
           user_account_id: user_account.id,
           user_uuid: user.uuid,
           auth_headers_json: auth_headers.to_json,
           saved_claim_id: saved_claim.id)
  end

  before do
    @provider = LighthouseGeneratePdfProvider.new(user.icn)
    allow_any_instance_of(BenefitsClaims::Configuration).to receive(:access_token)
      .and_return('access_token')
  end

  it_behaves_like 'generate pdf service provider'

  it 'retrieves a generated 526 pdf from the Lighthouse API' do
    VCR.use_cassette('lighthouse/benefits_claims/submit526/200_response_generate_pdf') do
      response = @provider.generate_526_pdf(submission.form['form526'].to_json, 'something')
      expect(response).not_to be_nil
    end
  end
end
