# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::Form526, type: :model do
  let(:auto_form) { build(:auto_established_claim, auth_headers: { some: 'data' }) }
  let(:json_api_payload) { auto_form.form_data.deep_symbolize_keys }
  let(:evss_payload) { File.read("#{::Rails.root}/modules/claims_api/spec/fixtures/form_526_evss.json") }

  describe 'validating attributes' do
    it 'should output to internal EVSS service' do
      evss_format = ClaimsApi::Form526.new(json_api_payload).to_internal
      expect(evss_format).to eq(evss_payload)
    end

    it 'should only process good payload to internal EVSS service' do
      error_payload = json_api_payload.merge(:'exit!' => true)
      evss_format = ClaimsApi::Form526.new(error_payload).to_internal
      expect(evss_format).to eq(evss_payload)
    end
  end
end
