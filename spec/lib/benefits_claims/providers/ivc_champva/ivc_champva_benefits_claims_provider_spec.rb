# frozen_string_literal: true

require 'rails_helper'
require 'support/benefits_claims/benefits_claims_provider'

RSpec.describe BenefitsClaims::Providers::IvcChampva::IvcChampvaBenefitsClaimsProvider do
  subject(:provider) { described_class.new(user) }

  let(:user) { create(:user) }

  after do
    RequestStore.clear!
  end

  it_behaves_like 'benefits claims provider'

  describe '#get_claims' do
    it 'returns empty data when no form_uuids are provided' do
      RequestStore.store[described_class::REQUEST_STORE_KEY] = nil

      expect(provider.get_claims).to eq({ 'data' => [] })
    end

    it 'returns claims grouped by form_uuid' do
      form_uuid = SecureRandom.uuid
      create(:ivc_champva_form, form_uuid:, file_name: 'main_form.pdf', created_at: 2.days.ago)
      create(:ivc_champva_form, form_uuid:, file_name: 'attachment.pdf', created_at: 1.day.ago)

      RequestStore.store[described_class::REQUEST_STORE_KEY] = [form_uuid]

      response = provider.get_claims
      claim = response['data'].first

      expect(response['data'].size).to eq(1)
      expect(claim['id']).to eq(form_uuid)
      expect(claim['attributes']['supportingDocuments'].size).to eq(2)
    end

    it 'ignores blank and duplicate form_uuids' do
      form_uuid = SecureRandom.uuid
      create(:ivc_champva_form, form_uuid:)

      RequestStore.store[described_class::REQUEST_STORE_KEY] = [form_uuid, '', form_uuid, '  ']

      response = provider.get_claims

      expect(response['data'].size).to eq(1)
      expect(response['data'].first['id']).to eq(form_uuid)
    end
  end

  describe '#get_claim' do
    it 'returns a single claim by form_uuid' do
      form_uuid = SecureRandom.uuid
      create(:ivc_champva_form, form_uuid:, file_name: 'main_form.pdf')

      response = provider.get_claim(form_uuid)

      expect(response['data']['id']).to eq(form_uuid)
    end

    it 'raises RecordNotFound when the form_uuid does not exist' do
      expect { provider.get_claim(SecureRandom.uuid) }
        .to raise_error(Common::Exceptions::RecordNotFound)
    end
  end
end
