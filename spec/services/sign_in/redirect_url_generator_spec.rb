# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::RedirectUrlGenerator do
  describe '#perform' do
    subject do
      SignIn::RedirectUrlGenerator.new(redirect_uri:, terms_code:, terms_redirect_uri:, params_hash:).perform
    end

    let(:redirect_uri) { Faker::Internet.url }
    let(:params_hash) do
      { param_key => param_value }
    end
    let(:param_value) { 'some-param' }
    let(:param_key) { :some_param }
    let(:terms_code) { 'some-terms-code' }
    let(:terms_redirect_uri) { 'some-terms-redirect-uri' }
    let(:expected_redirect_uri_with_params) { "#{redirect_uri}?#{params_hash.to_query}" }
    let(:expected_meta_tag) { "<meta http-equiv=\"refresh\" content=\"0;URL=#{expected_redirect_uri_with_params}\" />" }

    context 'when terms_code param is included' do
      let(:terms_code) { 'some-terms-code' }
      let(:terms_of_use_url) { "#{terms_redirect_uri}?#{embedded_params}" }
      let(:embedded_params) { "#{{ redirect_url: redirect_uri_with_params }.to_query}&amp;terms_code=#{terms_code}" }
      let(:redirect_uri_with_params) { "#{redirect_uri}?#{params_hash.to_query}" }
      let(:expected_log_message) { 'Redirecting to /terms-of-use' }
      let(:expected_log_payload) { { type: :sis } }

      it 'renders a meta refresh with expected redirect uri embedded in terms of use redirect' do
        expect(subject).to include(terms_of_use_url)
      end

      it 'logs expected message' do
        expect(Rails.logger).to receive(:info).with(expected_log_message, expected_log_payload)
        subject
      end
    end

    context 'when terms_code param is not included' do
      let(:terms_code) { nil }

      it 'renders a meta refresh with expected redirect uri with params' do
        expect(subject).to include(expected_meta_tag)
      end
    end
  end
end
