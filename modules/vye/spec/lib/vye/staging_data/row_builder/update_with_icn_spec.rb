# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Vye::StagingData::RowBuilder::UpdateWithIcn do
  describe 'happy path' do
    let :index do
      index = Hash.new { |h, k| h[k] = [] }
      index['333224444'].push(
        { full_name: 'John Q Public', ssn: '333224444' }
      )
      index
    end

    let :csv do
      {
        'icn' => 'x',
        'full_name' => 'John Q Public',
        'ssn' => '333-22-4444'
      }
    end

    it 'returns rows indexed by ssn' do
      result = Vye::StagingData::RowBuilder::UpdateWithIcn.new(index:, csv:).call
      expect(result.length).to eq(1)
      expect(result['333224444'].length).to eq(1)
      expect(result['333224444'].all? { |row| row[:icn].present? }).to be(true)
    end
  end

  describe 'matched icn' do
    let :index do
      index = Hash.new { |h, k| h[k] = [] }
      index['333224444'].push(
        { full_name: 'John Q Public', ssn: '333224444', icn: 'x' }
      )
      index
    end

    let :csv do
      {
        'icn' => 'x',
        'full_name' => 'John Q Public',
        'ssn' => '333-22-4444'
      }
    end

    it 'does not change anything' do
      result = Vye::StagingData::RowBuilder::UpdateWithIcn.new(index:, csv:).call
      expect(result.length).to eq(1)
      expect(result['333224444'].length).to eq(1)
    end
  end

  describe 'mismatched icn' do
    let :index do
      index = Hash.new { |h, k| h[k] = [] }
      index['333224444'].push(
        {
          full_name: 'John Q Public',
          ssn: '333224444',
          icn: 'y'
        }
      )
      index
    end

    let :csv do
      {
        'full_name' => 'John Q Public',
        'ssn' => '333224444',
        'icn' => 'z'
      }
    end

    it 'raises an error' do
      expect do
        Vye::StagingData::RowBuilder::UpdateWithIcn.new(index:, csv:).call
      end.to raise_error(RuntimeError, /icn missmatch/)
    end
  end
end
