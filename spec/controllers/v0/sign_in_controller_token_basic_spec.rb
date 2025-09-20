# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::SignInController, type: :controller do
  include_context 'token_setup'

  describe 'POST token' do
    context 'when grant_type param is not given' do
      let(:grant_type) { {} }
      let(:grant_type_value) { nil }
      let(:expected_error) { 'Grant type is not valid' }

      it_behaves_like 'token_error_response'
    end

    context 'when grant_type param is arbitrary' do
      let(:grant_type_value) { 'some-grant-type' }
      let(:expected_error) { 'Grant type is not valid' }

      it_behaves_like 'token_error_response'
    end
  end
end
