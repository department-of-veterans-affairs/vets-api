# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Vye::PendingDocument, type: :model do
  describe 'create' do
    let(:user_info) { FactoryBot.create(:vye_user_info) }

    it 'creates a record' do
      expect do
        attributes = { ssn: user_info.ssn, **FactoryBot.attributes_for(:vye_pending_document) }
        Vye::PendingDocument.create!(attributes)
      end.to change(Vye::PendingDocument, :count).by(1)
    end
  end
end
