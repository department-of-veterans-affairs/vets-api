# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IvcChampva::V1::UploadsController, type: :controller do
  describe 'sleep_study' do
    let(:logger_instance) { instance_double(ActiveSupport::Logger) }

    before do
      allow(Rails).to receive(:logger).and_return(logger_instance)
    end

    it 'sleeps for 5 seconds' do
      expect(logger_instance).to receive(:info).exactly(5).times
      subject.sleep_study
    end
  end
end
