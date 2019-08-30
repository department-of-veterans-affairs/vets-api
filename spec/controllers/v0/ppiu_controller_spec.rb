# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::PPIUController, type: :controller do
  let(:user) { create(:user, :loa3) }

  describe '#current_user_email' do
    context 'when vet360 is down' do
      it 'should return user email' do
        allow(controller).to receive(:current_user).and_return(user)
        expect(user).to receive(:vet360_contact_info).and_raise('foo')

        expect(controller.send(:current_user_email)).to eq(user.email)
      end
    end
  end
end
