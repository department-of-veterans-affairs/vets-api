# frozen_string_literal: true

require 'rails_helper'
require Vye::Engine.root / 'spec/rails_helper'

RSpec.describe Vye::DirectDepositChange, type: :model do
  let(:user_info) { FactoryBot.create(:vye_user_info) }

  describe 'create' do
    it 'creates a record' do
      expect do
        attributes = FactoryBot.attributes_for(:vye_direct_deposit_change)
        user_info.direct_deposit_changes.create!(attributes)
      end.to change(described_class, :count).by(1)
    end
  end

  describe 'creates a report' do
    before do
      old_bdn = FactoryBot.create(:vye_bdn_clone, is_active: true, export_ready: nil)
      new_bdn = FactoryBot.create(:vye_bdn_clone, is_active: false, export_ready: nil)

      FactoryBot.create_list(:vye_user_info, 7, :with_direct_deposit_changes, bdn_clone: old_bdn)

      new_bdn.activate!

      ssn = '123456789'
      profile = double(ssn:)
      find_profile_by_identifier = double(profile:)
      service = double(find_profile_by_identifier:)
      allow(MPI::Service).to receive(:new).and_return(service)
    end

    it 'produces report rows' do
      expect(described_class.report_rows.length).to eq(7)
    end

    it 'writes out a report' do
      io = StringIO.new

      expect do
        described_class.write_report(io)
      end.not_to raise_error

      io.rewind

      expect(io.string.scan("\n").count).to be(7)
    end
  end
end
