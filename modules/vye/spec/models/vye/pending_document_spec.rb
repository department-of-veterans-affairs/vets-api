# frozen_string_literal: true

require 'rails_helper'
require Vye::Engine.root / 'spec/rails_helper'

RSpec.describe Vye::PendingDocument, type: :model do
  describe 'create' do
    let(:user_profile) { create(:vye_user_profile) }

    it 'creates a record' do
      attributes = attributes_for(:vye_pending_document).merge(user_profile:)
      expect { described_class.create!(attributes) }.to change(described_class, :count).by(1)
    end
  end
end
