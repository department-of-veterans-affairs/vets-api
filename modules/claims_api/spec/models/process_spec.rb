# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::Process, type: :model do
  describe 'power of attorney process' do
    let(:power_of_attorney) { create(:power_of_attorney) }

    context 'when the power of attorney step type and status are valid' do
      it 'creates the process for the power of attorney' do
        process = ClaimsApi::Process.create!(processable: power_of_attorney,
                                             step_type: 'PDF_SUBMISSION',
                                             step_status: 'IN_PROGRESS')
        expect(process).to be_valid
      end
    end

    context 'when the power of attorney step type and status are invalid' do
      it 'raises an error' do
        expect do
          ClaimsApi::Process.create!(processable: power_of_attorney,
                                     step_type: 'INVALID_TYPE',
                                     step_status: 'INVALID_STATUS')
        end.to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    context 'when there is a next step' do
      it 'returns the next step' do
        process = ClaimsApi::Process.create!(processable: power_of_attorney,
                                             step_type: 'PDF_SUBMISSION',
                                             step_status: 'IN_PROGRESS')
        expect(process.next_step).to eq('POA_UPDATE')
      end
    end

    context 'when there is no next step' do
      it 'returns nil' do
        process = ClaimsApi::Process.create!(processable: power_of_attorney,
                                             step_type: 'CLAIMANT_NOTIFICATION',
                                             step_status: 'IN_PROGRESS')
        expect(process.next_step).to be_nil
      end
    end
  end
end
