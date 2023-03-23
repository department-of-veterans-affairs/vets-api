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

    it 'renders the oauth_get_form template' do
      expect(subject).to include('form id="oauth-form"')
    end

    it 'directs to the given redirect url set in the client configuration' do
      expect(subject).to include("action=\"#{redirect_uri}\"")
    end

    it 'includes params from param hash' do
      expect(subject).to include("value=\"#{param_value}\"")
    end
  end
end
