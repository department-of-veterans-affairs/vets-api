# frozen_string_literal: true

require 'rails_helper'

describe MockedAuthentication::RedirectUrlGenerator do
  describe '#perform' do
    subject { described_class.new(state:, code:, error:).perform }

    let(:expected_redirect_uri) { "#{redirect_uri}?#{code_param}#{error_param}#{state_param}" }
    let(:code_param) { "code=#{code}" }
    let(:error_param) { "&error=#{error}" }
    let(:state_param) { "&state=#{state}" }
    let(:redirect_uri) { URI.parse('/v0/sign_in/callback') }
    let(:state) { 'some-state' }
    let(:code) { 'some-code' }
    let(:error) { 'some-error' }

    it 'returns expected redirect_uri with expected params' do
      expect(subject).to eq(expected_redirect_uri)
    end

    context 'when error is present' do
      let(:error) { 'some-error' }

      it 'includes error query param in response' do
        expect(subject).to include(error_param)
      end
    end

    context 'when error is not present' do
      let(:error) { nil }

      it 'does not include error query param in response' do
        expect(subject).not_to include(error_param)
      end
    end

    context 'when code is present' do
      let(:code) { 'some-code' }

      it 'includes code query param in response' do
        expect(subject).to include(code_param)
      end
    end

    context 'when code is not present' do
      let(:code) { nil }

      it 'does not include error query param in response' do
        expect(subject).not_to include(code_param)
      end
    end
  end
end
