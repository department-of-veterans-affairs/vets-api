# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Vye::StagingData::RowBuilder::BuildFromIdme do
  describe 'happy path' do
    let :index do
      Hash.new { |h, k| h[k] = [] }
    end

    let :csv do
      {
        'idme_uuid' => 'testidme_uuid',
        'email' => 'test@email.com',
        'password' => 'testpassword',
        'first_name' => 'John',
        'middle_name' => 'Q',
        'last_name' => 'Public',
        'ssn' => '333-22-4444'
      }
    end

    it 'returns rows indexed by ssn' do
      expect(Vye::StagingData::RowBuilder::BuildFromIdme.new(index:, csv:).call['333224444'].length).to eq(1)
    end
  end

  describe 'matching row' do
    let :index do
      index = Hash.new { |h, k| h[k] = [] }
      index['333224444'].push(
        {
          idme_uuid: 'testidme_uuid',
          email: 'test@email.com',
          password: 'testpassword',
          first_name: 'John',
          middle_name: 'Q',
          last_name: 'Public',
          ssn: '333224444',
          icn: 'testicn'
        }
      )
      index
    end

    let :csv do
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
    end

    it 'returns rows indexed by ssn' do
      expect(Vye::StagingData::RowBuilder::BuildFromIdme.new(index:, csv:).call['333224444'].length).to eq(1)
    end
  end

  describe 'mismatching password' do
    let :index do
      index = Hash.new { |h, k| h[k] = [] }
      index['333224444'].push(
        {
          idme_uuid: 'testidme_uuid',
          email: 'test@email.com',
          password: 'testpassword1',
          first_name: 'John',
          middle_name: 'Q',
          last_name: 'Public',
          ssn: '333224444',
          icn: 'testicn'
        }
      )
      index
    end

    let :csv do
      {
        'idme_uuid' => 'testidme_uuid',
        'email' => 'test@email.com',
        'password' => 'testpassword2',
        'first_name' => 'John',
        'middle_name' => 'Q',
        'last_name' => 'Public',
        'ssn' => '333-22-4444',
        'icn' => 'testicn'
      }
    end

    it 'raises an exception' do
      expect do
        Vye::StagingData::RowBuilder::BuildFromIdme.new(index:, csv:).call
      end.to raise_error(RuntimeError)
    end
  end

  describe 'mismatching email' do
    let :index do
      index = Hash.new { |h, k| h[k] = [] }
      index['333224444'].push(
        {
          idme_uuid: 'testidme_uuid',
          email: 'test1@email.com',
          password: 'testpassword',
          first_name: 'John',
          middle_name: 'Q',
          last_name: 'Public',
          ssn: '333224444',
          icn: 'testicn'
        }
      )
      index
    end

    let :csv do
      {
        'idme_uuid' => 'testidme_uuid',
        'email' => 'test2@email.com',
        'password' => 'testpassword',
        'first_name' => 'John',
        'middle_name' => 'Q',
        'last_name' => 'Public',
        'ssn' => '333-22-4444',
        'icn' => 'testicn'
      }
    end

    it 'returns rows indexed by ssn' do
      expect do
        Vye::StagingData::RowBuilder::BuildFromIdme.new(index:, csv:).call
      end.to raise_error(RuntimeError)
    end
  end
end
