# frozen_string_literal: true

require 'rails_helper'
require 'pension_21p527ez/pension_military_information'

RSpec.describe Pension21p527ez::PensionMilitaryInformation do
  let(:user) { build(:user, :loa3) }

  describe '#format_service_branches_for_pensions' do
    it 'returns an object of valid branches' do
      expect(described_class.new(user).format_service_branches_for_pensions(%w[
                                                                              army
                                                                              navy
                                                                              airForce
                                                                              coastGuard
                                                                              marineCorps
                                                                              spaceForce
                                                                              usphs
                                                                              noaa
                                                                            ])).to eq({
                                                                                        'army' => true,
                                                                                        'navy' => true,
                                                                                        'airForce' => true,
                                                                                        'coastGuard' => true,
                                                                                        'marineCorps' => true,
                                                                                        'spaceForce' => true,
                                                                                        'usphs' => true,
                                                                                        'noaa' => true
                                                                                      })
    end

    it 'filters out invalid branches' do
      expect(described_class.new(user).format_service_branches_for_pensions(['army', nil])).to eq({
                                                                                                    'army' => true
                                                                                                  })
    end
  end
end
