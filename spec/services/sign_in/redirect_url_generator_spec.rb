# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::RedirectUrlGenerator do
  describe '#perform' do
    subject do
      SignIn::RedirectUrlGenerator.new(redirect_uri:, params_hash:).perform
    end

    let(:redirect_uri) { Faker::Internet.url }
    let(:params_hash) do
      { param_key => param_value }
    end
    let(:param_value) { 'some-param' }
    let(:param_key) { :some_param }
    let(:expected_redirect_uri_with_params) { "#{redirect_uri}?#{params_hash.to_query}" }
    let(:expected_meta_tag) { "<meta http-equiv=\"refresh\" content=\"0;URL=#{expected_redirect_uri_with_params}\" />" }

    it 'renders a meta refresh with expected redirect uri with params' do
      expect(subject).to include(expected_meta_tag)
    end
  end
end
