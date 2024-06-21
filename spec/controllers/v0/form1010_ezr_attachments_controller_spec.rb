# frozen_string_literal: true

require 'rails_helper'
require 'support/1010_forms/shared_examples/form_attachment'

RSpec.describe V0::Form1010EzrAttachmentsController, type: :controller do
  describe '::FORM_ATTACHMENT_MODEL' do
    it_behaves_like 'inherits the FormAttachment model'
  end

  describe '#create' do
    context "with the 'form1010_ezr_attachments_controller' flipper enabled" do
      context 'unauthenticated' do
        it 'returns a 401' do
          post(:create)

          expect(response).to have_http_status(:unauthorized)
          expect(response.body).to include('Not authorized')
        end
      end

      context 'authenticated' do
        before do
          current_user = build(:evss_user, :loa3, icn: '1013032368V065534')
          sign_in_as(current_user)
        end

        it_behaves_like 'create 1010 form attachment'
      end
    end

    context "with the 'form1010_ezr_attachments_controller' flipper disabled" do
      before do
        Flipper.disable(:form1010_ezr_attachments_controller)
      end

      it 'fails' do
        expect { post(:create) }.to raise_error(
          AbstractController::ActionNotFound,
          "The action 'create' could not be found for V0::Form1010EzrAttachmentsController"
        )
      end
    end
  end
end
