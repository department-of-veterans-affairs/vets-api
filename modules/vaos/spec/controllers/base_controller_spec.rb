# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VAOS::BaseController, type: :controller do
  describe '#authorize' do
    let(:current_user) { build(:user, :loa3) }

    context 'when current user does not have an icn' do
      it 'raises a Common::Exceptions::Forbidden exception' do
        allow_any_instance_of(User).to receive(:icn).and_return(nil)
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(current_user)

        expect { subject.send(:authorize) }.to raise_error(Common::Exceptions::Forbidden)
      end
    end
  end
end
