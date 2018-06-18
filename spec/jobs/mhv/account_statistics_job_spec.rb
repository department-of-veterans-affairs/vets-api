# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MHV::AccountStatisticsJob, type: :job do
  describe 'AccountStatisticsJob' do
    it 'successfully runs the job' do
      expect(MHV::AccountStatisticsJob.new.perform).to eq(true)
    end
  end
end
