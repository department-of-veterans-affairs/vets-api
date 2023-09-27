# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HCA::AnonEncryptedSubmissionJob, type: :job do
  let(:health_care_application) { create(:health_care_application) }

  describe 'when job has failed' do
    it 'sets the health_care_application state to failed' do
      begin
        described_class.new.perform(nil, nil, health_care_application.id, nil)
      rescue
        nil
      end

      expect(health_care_application.reload.state).to eq('failed')
    end
  end
end
