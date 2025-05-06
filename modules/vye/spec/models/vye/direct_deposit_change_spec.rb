# frozen_string_literal: true

require 'rails_helper'
require Vye::Engine.root / 'spec/rails_helper'

RSpec.describe Vye::DirectDepositChange, type: :model do
  let(:user_info) { create(:vye_user_info) }

  describe 'create' do
    it 'creates a record' do
      expect do
        attributes = attributes_for(:vye_direct_deposit_change)
        user_info.direct_deposit_changes.create!(attributes)
      end.to change(described_class, :count).by(1)
    end
  end

  describe 'creates a report' do
    before do
      old_bdn = create(:vye_bdn_clone, is_active: true, export_ready: nil)
      new_bdn = create(:vye_bdn_clone, is_active: false, export_ready: nil)

      create_list(:vye_user_info, 7, :with_direct_deposit_changes, bdn_clone: old_bdn)

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

    it 'writes out a report where acct_types are correctly enumerated' do
      io = StringIO.new

      expect do
        described_class.write_report(io)
      end.not_to raise_error

      nineth_index_of_lines = io.string.split(/[\n]/).map { |x| x.split(/[,]/)[9] }.join

      expect(nineth_index_of_lines.match?(/[CS]{7}/)).to be(true)
    end

    it 'writes out a report where phone numbers are correctly formatted' do
      io = StringIO.new

      expect do
        described_class.write_report(io)
      end.not_to raise_error

      phone_numbers_in_lines =
        io
        .string
        .split(/[\n]/)
        .map { |x| x.split(/[,]/).values_at(5, 6, 13) }
        .flatten

      expect(phone_numbers_in_lines.all? do |x|
        x == ' ' || x.match?(/\d{3}[-]\d{3}[-]\d{4}/)
      end).to be(true)
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
