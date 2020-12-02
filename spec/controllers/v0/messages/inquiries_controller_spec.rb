# frozen_string_literal: true

require 'rails_helper'
require 'support/controller_spec_helper'

RSpec.describe V0::Messages::InquiriesController, type: :controller do
  context 'when not signed in' do
    it 'renders :unauthorized' do
      get :index

      expect(response).to have_http_status(:unauthorized)
    end
  end

  context 'when signed in' do
    let(:user) { FactoryBot.build(:user) }

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
      end
    end
  end
end
