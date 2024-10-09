# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Form4142StatusPollingRecord, type: :model do

  describe 'successful creation' do
    it 'when all attrs provided' do
        polling_record = Form4142StatusPollingRecord.new(benefits_intake_uuid: '123', submission_id: 123, submission_class: 'Class')
        polling_record.save!
        expect(polling_record.status).to eq('pending')
    end
  end
  
  describe 'errors' do
    it 'when missing submission_id' do
      expect do
        polling_record = Form4142StatusPollingRecord.new(benefits_intake_uuid: '123')
        polling_record.save!
      end.to raise_error(ActiveRecord::RecordInvalid)
    end
    
    it 'when missing benefits_intake_uuid' do
      expect do
        polling_record = Form4142StatusPollingRecord.new(submission_id: 123)
        polling_record.save!
      end.to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'when missing submission_id' do
      expect do
        polling_record = Form4142StatusPollingRecord.new(benefits_intake_uuid: '123')
        polling_record.save!
      end.to raise_error(ActiveRecord::RecordInvalid)
    end
    
    it 'when missing both benefits_intake_uuid and submission_id' do
      expect do
        polling_record = Form4142StatusPollingRecord.new
        polling_record.save!
      end.to raise_error(ActiveRecord::RecordInvalid)
    end

    

  end

end
