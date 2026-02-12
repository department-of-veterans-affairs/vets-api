# frozen_string_literal: true

require 'rails_helper'
require 'support/benefits_claims/benefits_claims_provider'

RSpec.describe BenefitsClaims::Providers::IvcChampva::IvcChampvaBenefitsClaimsProvider do
  subject(:provider) { described_class.new(user) }

  let(:user) { create(:user) }

  it_behaves_like 'benefits claims provider'

  describe '#get_claims' do
    it 'returns empty data when no matching forms exist for the user' do
      expect(provider.get_claims).to eq({ 'data' => [] })
    end

    it 'returns claims grouped by form_uuid' do
      form_uuid = SecureRandom.uuid
      create(
        :ivc_champva_form,
        form_uuid:,
        email: user.email,
        file_name: 'main_form.pdf',
        created_at: 2.days.ago
      )
      create(
        :ivc_champva_form,
        form_uuid:,
        email: user.email,
        file_name: 'attachment.pdf',
        created_at: 1.day.ago
      )

      response = provider.get_claims
      claim = response['data'].first

      expect(response['data'].size).to eq(1)
      expect(claim['id']).to eq(form_uuid)
      expect(claim['attributes']['supportingDocuments'].size).to eq(2)
    end

    it 'returns only forms matching the user email' do
      form_uuid = SecureRandom.uuid
      create(:ivc_champva_form, form_uuid:, email: user.email)
      create(:ivc_champva_form, form_uuid: SecureRandom.uuid, email: 'other.user@example.com')

      response = provider.get_claims

      expect(response['data'].size).to eq(1)
      expect(response['data'].first['id']).to eq(form_uuid)
    end
  end

  describe '#get_claim' do
    it 'returns a single claim by form_uuid' do
      form_uuid = SecureRandom.uuid
      create(:ivc_champva_form, form_uuid:, email: user.email, file_name: 'main_form.pdf')

      response = provider.get_claim(form_uuid)

      expect(response['data']['id']).to eq(form_uuid)
    end

    it 'raises RecordNotFound when the form_uuid does not exist' do
      expect { provider.get_claim(SecureRandom.uuid) }
        .to raise_error(Common::Exceptions::RecordNotFound)
    end
  end
end
