# frozen_string_literal: true

require 'rails_helper'

describe EMIS::Models::MilitaryServiceEpisode do
  describe '#branch_of_service' do
    it 'converts the code into a branch name' do
      expect(described_class.new(branch_of_service_code: 'F').branch_of_service).to eq(
        'Air Force'
      )
    end
  end

  describe '#hca_branch_of_service' do
    it 'converts the code into a branch name' do
      expect(described_class.new(branch_of_service_code: 'F').hca_branch_of_service).to eq(
        'air force'
      )
    end
  end
end
