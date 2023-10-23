# frozen_string_literal: true

require 'rails_helper'
require 'vye/egress_files'

RSpec.describe VYE::EgressFiles do
  describe '#address_changes_filename' do
    it 'returns a string' do
      expect(VYE::EgressFiles.address_changes_filename).to be_a(String)
    end
  end

  describe '#direct_deposit_filename' do
    it 'returns a string' do
      expect(VYE::EgressFiles.direct_deposit_filename).to be_a(String)
    end
  end

  describe '#no_change_enrollment_filename' do
    it 'returns a string' do
      expect(VYE::EgressFiles.no_change_enrollment_filename).to be_a(String)
    end
  end
end
