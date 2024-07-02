# frozen_string_literal: true

require 'rails_helper'
require 'support/1010_forms/shared_examples/form_attachment'

RSpec.describe V0::Form1010EzrAttachmentsController, type: :controller do
  let(:current_user) { build(:evss_user, :loa3, icn: '1013032368V065534') }

  describe '::FORM_ATTACHMENT_MODEL' do
    it_behaves_like 'inherits the FormAttachment model'
  end

  describe '#create' do
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
end
