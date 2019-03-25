# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::Form526, type: :model do
  let(:auto_form) { build(:auto_established_claim, auth_headers: { some: 'data' }) }
  let(:json_api_payload) { auto_form.form_data.deep_symbolize_keys }
  let(:evss_payload) { File.read("#{::Rails.root}/modules/claims_api/spec/fixtures/form_526_evss.json") }
  let(:invalid_auto_form) { build(:invalid_auto_established_claim, auth_headers: { some: 'data' }) }
  let(:invalid_json_api_payload) { invalid_auto_form.form_data.deep_symbolize_keys }

  describe 'validating attributes' do
    it 'should output to internal EVSS service' do
      evss_format = ClaimsApi::Form526.new(json_api_payload).to_internal
      expect(evss_format).to eq(evss_payload)
    end

    it 'should only process good payload to internal EVSS service' do
      error_payload = json_api_payload.merge('exit!': true)
      evss_format = ClaimsApi::Form526.new(error_payload).to_internal
      expect(evss_format).to eq(evss_payload)
    end
  end

  describe 'validating nested fields' do
    let(:claim) { ClaimsApi::Form526.new(invalid_json_api_payload) }
    before do
      claim.valid?
    end

    it 'should require currentMailingAddress subfields' do
      expect(claim.errors[:currentMailingAddress].size).to eq(6)
    end

    it 'should require disability subfields' do
      expect(claim.errors[:disabilities].size).to eq(2)
    end

    it 'should require service period subfields' do
      expect(claim.errors[:servicePeriods].size).to eq(3)
    end

    it 'should error when current address is missing all together' do
      invalid_json_api_payload[:veteran].delete(:currentMailingAddress)
      claim = ClaimsApi::Form526.new(invalid_json_api_payload)
      claim.valid?
      expect(claim.errors[:veteran].size).to eq(1)
    end

    it 'should error when current address is wrong format' do
      invalid_json_api_payload[:veteran][:currentMailingAddress] = 1337
      claim = ClaimsApi::Form526.new(invalid_json_api_payload)
      claim.valid?
      expect(claim.errors[:currentMailingAddress].size).to eq(1)
    end
  end
end
