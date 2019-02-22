# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::Form526, type: :model do
  let(:auto_form) { build(:auto_established_claim, auth_headers: { some: 'data' }) }
  let(:json_api_payload) { JSON.parse(auto_form.form_data)['data']['attributes'].deep_symbolize_keys }
  let(:evss_payload) { File.read("#{::Rails.root}/modules/claims_api/spec/fixtures/form_526_evss.json") }

  describe 'validating attributes' do
    xit 'should output to internal EVSS service' do
      expect(Form526).to receive(:new).with(json_api_payload)
      expect(Form526.to_internal).to eq(evss_payload)
    end
  end
end
