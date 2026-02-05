# frozen_string_literal: true

require 'rails_helper'
require 'disability_compensation/factories/api_provider_factory'

RSpec.describe ApiProviderFactory do
  let(:current_user) { build(:user, :loa3) }
  let(:auth_headers) do
    EVSS::DisabilityCompensationAuthHeaders.new(current_user).add_headers(EVSS::AuthHeaders.new(current_user).to_h)
  end
  let(:icn) { current_user.icn.to_s }

  context 'rated_disabilities' do
    it 'provides a Lighthouse rated disabilities provider' do
      expect(provider(:lighthouse).class).to equal(LighthouseRatedDisabilitiesProvider)
    end

    it 'returns the correct factory type' do
      factory = ApiProviderFactory.new(
        type: ApiProviderFactory::FACTORIES[:rated_disabilities],
        provider: nil,
        options: { icn:, auth_headers: },
        current_user: nil,
        feature_toggle: nil
      )
      expect(factory.type).to equal(:rated_disabilities)
    end

    it 'throw error if provider unknown' do
      expect do
        ApiProviderFactory.call(
          type: ApiProviderFactory::FACTORIES[:rated_disabilities],
          provider: :random,
          options: { icn:, auth_headers: },
          current_user: nil,
          feature_toggle: nil
        )
      end.to raise_error NotImplementedError
    end

    def provider(api_provider = nil, feature_toggle = nil)
      ApiProviderFactory.call(
        type: ApiProviderFactory::FACTORIES[:rated_disabilities],
        provider: api_provider,
        options: { icn:, auth_headers: },
        current_user: nil,
        feature_toggle:
      )
    end
  end

  context 'intent_to_file' do
    it 'provides a Lighthouse intent to file provider' do
      expect(provider(:lighthouse).class).to equal(LighthouseIntentToFileProvider)
    end

    it 'throw error if provider unknown' do
      expect do
        provider(:random)
      end.to raise_error NotImplementedError
    end

    def provider(api_provider = nil)
      ApiProviderFactory.call(
        type: ApiProviderFactory::FACTORIES[:intent_to_file],
        provider: api_provider,
        options: {},
        current_user:,
        feature_toggle: nil
      )
    end
  end

  context 'claims service' do
    def provider(api_provider = nil)
      ApiProviderFactory.call(
        type: ApiProviderFactory::FACTORIES[:claims],
        provider: api_provider,
        options: { icn: current_user.icn, auth_headers: },
        current_user:,
        feature_toggle: nil
      )
    end

    it 'provides a Lighthouse claims service provider' do
      expect(provider(:lighthouse).class).to equal(LighthouseClaimsServiceProvider)
    end

    it 'throw error if provider unknown' do
      expect do
        provider(:random)
      end.to raise_error NotImplementedError
    end
  end

  context 'ppiu direct deposit' do
    it 'provides a Lighthouse ppiu direct deposit provider' do
      expect(provider(:lighthouse).class).to equal(LighthousePPIUProvider)
    end

    it 'throw error if provider unknown' do
      expect do
        provider(:random)
      end.to raise_error NotImplementedError
    end

    def provider(api_provider = nil)
      ApiProviderFactory.call(
        type: ApiProviderFactory::FACTORIES[:ppiu],
        provider: api_provider,
        options: {},
        current_user:,
        feature_toggle: nil
      )
    end
  end

  context 'brd' do
    def provider(api_provider = :lighthouse)
      ApiProviderFactory.call(
        type: ApiProviderFactory::FACTORIES[:brd],
        provider: api_provider,
        options: {},
        current_user:,
        feature_toggle: nil
      )
    end

    it 'provides a Lighthouse brd provider' do
      expect(provider(:lighthouse).class).to equal(LighthouseBRDProvider)
    end

    it 'throw error if provider unknown' do
      expect do
        provider(:random)
      end.to raise_error NotImplementedError
    end
  end

  context 'generate_pdf' do
    def provider(api_provider = nil)
      ApiProviderFactory.call(
        type: ApiProviderFactory::FACTORIES[:generate_pdf],
        provider: api_provider,
        options: { auth_headers: },
        current_user:,
        feature_toggle: nil
      )
    end

    it 'provides a Lighthouse generate_pdf provider' do
      expect(provider(:lighthouse).class).to equal(LighthouseGeneratePdfProvider)
    end

    it 'throw error if provider unknown' do
      expect do
        provider(:random)
      end.to raise_error NotImplementedError
    end
  end

  context 'upload supplemental document' do
    let(:submission) { create(:form526_submission) }
    # BDD Document Type
    let(:va_document_type) { 'L023' }

    def provider(api_provider = nil)
      ApiProviderFactory.call(
        type: ApiProviderFactory::FACTORIES[:supplemental_document_upload],
        provider: api_provider,
        options: {
          form526_submission: submission,
          document_type: va_document_type,
          statsd_metric_prefix: 'my_stats_metric_prefix'
        },
        current_user:,
        feature_toggle: nil
      )
    end

    it 'provides an EVSS upload_supplemental_document provider' do
      expect(provider(:evss).class).to equal(EVSSSupplementalDocumentUploadProvider)
    end

    it 'provides a Lighthouse upload_supplemental_document provider' do
      expect(provider(:lighthouse).class).to equal(LighthouseSupplementalDocumentUploadProvider)
    end

    it 'throw error if provider unknown' do
      expect do
        provider(:random)
      end.to raise_error NotImplementedError
    end

    context 'for 0781 uploads' do
      def provider
        ApiProviderFactory.call(
          type: ApiProviderFactory::FACTORIES[:supplemental_document_upload],
          options: {
            form526_submission: submission,
            document_type: 'L228', # 0781 VA Doc Type
            statsd_metric_prefix: 'my_stats_metric_prefix_0781'
          },
          current_user:,
          feature_toggle: ApiProviderFactory::FEATURE_TOGGLE_UPLOAD_0781
        )
      end

      it 'provides a SupplementalDocumentUploadProvider based on a Flipper' do
        Flipper.enable(ApiProviderFactory::FEATURE_TOGGLE_UPLOAD_0781) # rubocop:disable Project/ForbidFlipperToggleInSpecs
        expect(provider.class).to equal(LighthouseSupplementalDocumentUploadProvider)

        Flipper.disable(ApiProviderFactory::FEATURE_TOGGLE_UPLOAD_0781) # rubocop:disable Project/ForbidFlipperToggleInSpecs
        expect(provider.class).to equal(EVSSSupplementalDocumentUploadProvider)
      end
    end
  end
end
