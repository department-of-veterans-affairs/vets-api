# frozen_string_literal: true

require 'rails_helper'
require 'support/controller_spec_helper'

RSpec.describe V0::ContactUs::InquiriesController, type: :controller do
  describe 'index' do
    context 'when not signed in' do
      it 'renders :unauthorized' do
        get :index

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when signed in' do
      let(:user) { build(:user) }

      before do
        sign_in_as(user)
      end

      describe '#index' do
        context 'when Flipper :get_help_messages is' do
          context 'disabled' do
            it 'renders :not_implemented' do
              expect(Flipper).to receive(:enabled?).with(:get_help_messages).and_return(false)

              get :index

              expect(response).to have_http_status(:not_implemented)
            end
          end

          context 'enabled' do
            it 'renders :not_implemented' do
              expect(Flipper).to receive(:enabled?).with(:get_help_messages).and_return(true)

              get :index

              expect(response).to have_http_status(:ok)
            end
          end
        end
      end
    end
  end

  describe '#create' do
    def send_create
      post(:create, params: { ask: { form: } })
    end

    before do
      allow(Flipper).to receive(:enabled?).and_call_original
    end

    context 'when Flipper :get_help_ask_form is' do
      context 'disabled' do
        it 'renders :not_implemented' do
          expect(Flipper).to receive(:enabled?).with(:get_help_ask_form).and_return(false)

          post :create

          expect(response).to have_http_status(:not_implemented)
        end
      end

      context 'enabled' do
        context 'when form is valid' do
          it 'returns 201 CREATED with confirmationNumber and dateSubmitted' do
            form_data = get_fixture('ask/minimal').to_json
            params = { inquiry: { form: form_data } }
            claim = build(:ask, form: form_data)

            expect(SavedClaim::Ask).to receive(:new).with(
              form: form_data
            ).and_return(
              claim
            )

            expect(Flipper).to receive(:enabled?).with(:get_help_ask_form).and_return(true)

            post(:create, params:)

            expect(response).to have_http_status(:created)

            expect(JSON.parse(response.body)).to include('confirmationNumber', 'dateSubmitted')
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

            post(:create, params:)

            expect(JSON.parse(response.body)['errors']).not_to be_empty

            expect(response).to have_http_status(:unprocessable_entity)
          end
        end
      end
    end
  end
end
