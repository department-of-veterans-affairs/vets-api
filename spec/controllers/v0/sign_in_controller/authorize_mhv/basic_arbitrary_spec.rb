# frozen_string_literal: true

require 'rails_helper'
require_relative '../sign_in_controller_shared_examples_spec'

RSpec.describe V0::SignInController, type: :controller do
  include_context 'sign_in_controller_shared_setup'
  include_context 'authorize_setup'

  context 'when type param is mhv' do
    let(:type_value) { SignIn::Constants::Auth::MHV }
    let(:expected_type_value) { SignIn::Constants::Auth::MHV }

    context 'and operation param is arbitrary' do
      let(:operation_value) { 'some-operation-value' }
      let(:expected_error) { 'Operation is not valid' }

      it_behaves_like 'error response'
    end
  end
end
