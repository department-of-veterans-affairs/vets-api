# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Vye::StagingData::Rows do
  describe '#idme_csv_each' do
    let(:rows) do
      idme_files = ['x']
      icn_files = []
      Vye::StagingData::Rows.new(idme_files:, icn_files:)
    end

    it 'raises an exception' do
      expect do
        rows.get
      end.to raise_error(Errno::ENOENT)
    end
  end

  describe '#icn_csv_each' do
    let(:rows) do
      idme_files = []
      icn_files = ['x']
      Vye::StagingData::Rows.new(idme_files:, icn_files:)
    end

    it 'raises an exception' do
      expect do
        rows.get
      end.to raise_error(Errno::ENOENT)
    end
  end

  describe '#index' do
    let(:rows) do
      idme_files = ['/dev/null']
      icn_files = ['/dev/null']
      Vye::StagingData::Rows.new(idme_files:, icn_files:)
    end

    it 'returns a Hash' do
      expect(rows.index.blank?).to be(true)
    end
  end

  describe '#get' do
    let(:rows) do
      idme_files = ['/dev/null']
      icn_files = ['/dev/null']
      Vye::StagingData::Rows.new(idme_files:, icn_files:)
    end

    let(:index) do
      index = Hash.new { |h, k| h[k] = [] }
      index['333224445'].push(
        {
          idme_uuid: 'testidme_uuid',
          email: 'test@email.com',
          password: 'testpassword',
          first_name: 'John',
          middle_name: 'Q',
          last_name: 'Public',
          ssn: '333224445'
        }
      )
      index
    end

    before do
      allow(rows).to receive(:index).and_return(index)

      allow(rows).to receive(:idme_csv_each).and_yield(
        {
          'idme_uuid' => 'testidme_uuid',
          'email' => 'test@email.com',
          'password' => 'testpassword',
          'first_name' => 'John',
          'middle_name' => 'Q',
          'last_name' => 'Public',
          'ssn' => '333-22-4444',
          'icn' => 'testicn'
        }
      )

      allow(rows).to receive(:icn_csv_each).and_yield(
        {
          'full_name' => 'John Q Public',
          'ssn' => '333-22-4444',
          'icn' => 'z'
        }
      )
    end

    it 'returns a Array' do
      expect(rows.get).to be_a(Array)
    end
  end
end
