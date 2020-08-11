# frozen_string_literal: true

require 'rails_helper'
require 'support/controller_spec_helper'

RSpec.describe V0::Ask::AsksController, type: :controller do
  # Test Cases:
  # If the feature toggle is on or off
  #   If on and you get a form return 200
  #   If off then do nothing and return an error
  # If the form data is valid or invalid
  describe '#create' do
    def send_create
      post(:create, params: { ask: { form: form } })
    end

    context 'when Flipper :get_help_ask_form is' do
      context 'disabled' do
        it 'renders :service_unavailable' do
          expect(Flipper).to receive(:enabled?).with(:get_help_ask_form).and_return(false)

          post :create

          expect(response).to have_http_status(:service_unavailable)
        end
      end

      context 'enabled' do
        it 'returns 200' do
          expect(Flipper).to receive(:enabled?).with(:get_help_ask_form).and_return(true)

          post :create

          expect(response).to have_http_status(:ok)
        end
      end
    end
  end
end
