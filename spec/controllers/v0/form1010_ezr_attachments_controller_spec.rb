# frozen_string_literal: true

require 'rails_helper'
require 'support/1010_forms/shared_examples/form_attachment'

RSpec.describe V0::Form1010EzrAttachmentsController, type: :controller do
  let(:current_user) { build(:evss_user, :loa3, icn: '1013032368V065534') }

  before(:all) do
    Flipper.enable(:form1010_ezr_attachments_controller)
  end

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
          sign_in(current_user)
        end

        it_behaves_like 'create 1010 form attachment'
      end
    end

    context "with the 'form1010_ezr_attachments_controller' flipper disabled" do
      before do
        Flipper.disable(:form1010_ezr_attachments_controller)
      end

      it 'returns an error' do
        sign_in(current_user)

        post(:create)
        expect(response).to have_http_status(:internal_server_error)

        response_body = JSON.parse(response.body)
        error = response_body['errors'].first
        meta_exception = error.dig('meta', 'exception')

        expect(meta_exception).to eq(
          "The 'create' route for V0::Form1010EzrAttachmentsController is currently unavailable"
        )
      end
    end
  end
end
