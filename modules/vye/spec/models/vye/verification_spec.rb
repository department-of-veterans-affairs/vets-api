# frozen_string_literal: true

require 'rails_helper'
require Vye::Engine.root / 'spec/rails_helper'

RSpec.describe Vye::Verification, type: :model do
  it 'is valid with valid attributes' do
    address_change = build_stubbed(:vye_verification)
    expect(address_change).to be_valid
  end

  describe 'creates a report' do
    before do
      old_bdn = create(:vye_bdn_clone, is_active: true, export_ready: nil)
      new_bdn = create(:vye_bdn_clone, is_active: false, export_ready: nil)

      create_list(:vye_user_info, 7, :with_verified_awards, bdn_clone: old_bdn)

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

    it 'writes out a report where the stub_nm is left aligned' do
      io = StringIO.new

      expect do
        described_class.write_report(io)
      end.not_to raise_error

      stub_nm_list = io.string.split(/[\n]/).map { |x| x.slice(0, 7) }.flatten

      expect(stub_nm_list.all? { |x| x.start_with?(/\S/) }).to be(true)
    end

    it 'writes out the ssn with the last 2 digits in front of the first 7' do
      io = StringIO.new

      described_class.write_report(io)

      stub_td_list = io.string.split(/[\n]/).map { |x| x.slice(7, 9) }.flatten

      expect(stub_td_list.all? { |x| x.eql?('891234567') }).to be(true)
    end
  end
end
