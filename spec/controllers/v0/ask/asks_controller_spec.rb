# frozen_string_literal: true

require 'rails_helper'
require 'support/controller_spec_helper'

RSpec.describe V0::Ask::AsksController, type: :controller do
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
        context 'when form is valid' do
          it 'returns 200 OK' do
            form_data = get_fixture('ask/minimal').to_json
            params = { inquiry: { form: form_data } }
            claim = build(:ask, form: form_data)

            expect(SavedClaim::Ask).to receive(:new).with(
              form: form_data
            ).and_return(
              claim
            )

            expect(Flipper).to receive(:enabled?).with(:get_help_ask_form).and_return(true)

            post :create, params: params

            expect(response).to have_http_status(:ok)
          end
        end

        context 'when form is invalid' do
          it 'raises error' do
            form_data = {}.to_json
            params = { inquiry: { form: form_data } }
            claim = build(:ask, form: form_data)

            expect(SavedClaim::Ask).to receive(:new).with(
              form: form_data
            ).and_return(
              claim
            )

            expect(Flipper).to receive(:enabled?).with(:get_help_ask_form).and_return(true)

            post :create, params: params

            expect(JSON.parse(response.body)['errors']).not_to be_empty

            expect(response).to have_http_status(:unprocessable_entity)
          end
        end
      end
    end
  end
end
