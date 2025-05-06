# frozen_string_literal: true

require 'rails_helper'
require Vye::Engine.root / 'spec/rails_helper'

RSpec.describe Vye::AddressChange, type: :model do
  it 'is valid with valid attributes' do
    address_change = build_stubbed(:vye_address_change)
    expect(address_change).to be_valid
  end

  describe 'caching for next BDN clone' do
    before do
      old_bdn = create(:vye_bdn_clone, is_active: true, export_ready: nil)
      new_bdn = create(:vye_bdn_clone, is_active: false, export_ready: nil)

      7.times do
        user_profile = create(:vye_user_profile)
        create(:vye_user_info, :with_address_changes, bdn_clone: old_bdn, user_profile:)
        create(:vye_user_info, bdn_clone: new_bdn, user_profile:)
      end

      new_bdn.activate!

      ssn = '123456789'
      profile = double(ssn:)
      find_profile_by_identifier = double(profile:)
      service = double(find_profile_by_identifier:)
      allow(MPI::Service).to receive(:new).and_return(service)
    end

    it 'produces report rows' do
      expect do
        described_class.cache_new_address_changes
      end.to change(described_class, :count).by(7)
    end
  end

  describe 'creates a report' do
    before do
      old_bdn = create(:vye_bdn_clone, is_active: true, export_ready: nil)
      new_bdn = create(:vye_bdn_clone, is_active: false, export_ready: nil)

      create_list(:vye_user_info, 7, :with_address_changes, bdn_clone: old_bdn)

      new_bdn.activate!

      ssn = '123456789'
      profile = double(ssn:)
      find_profile_by_identifier = double(profile:)
      service = double(find_profile_by_identifier:)
      allow(MPI::Service).to receive(:new).and_return(service)
    end

    it 'produces report rows' do
      expect(described_class.each_report_row.to_a.length).to eq(7)
    end

    it 'writes out a report' do
      io = StringIO.new

      expect do
        described_class.write_report(io)
      end.not_to raise_error

      io.rewind

      expect(io.string.scan("\n").count).to be(7)
    end

    it 'writes out a report where all field are left aligned and have at least a length of one' do
      io = StringIO.new

      expect do
        described_class.write_report(io)
      end.not_to raise_error

      fields_across_all_lines = io.string.split(/[\n]/).map { |x| x.split(/[,]/) }.flatten

      expect(fields_across_all_lines.all? { |x| x == ' ' || x.start_with?(/\S/) }).to be(true)
    end
  end
end
