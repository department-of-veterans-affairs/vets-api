# frozen_string_literal: true
require 'rails_helper'

RSpec.describe EducationForm::GenerateSpoolFiles, type: :model, form: :education_benefits do
  subject { described_class.new }
  context '#malformed_claim_ids' do
    it 'should return a list of ids for each model type' do
      expect(subject.malformed_claim_ids).to include(:education_benefits_claims,
                                                     :saved_claims,
                                                     :education_benefits_submissions,
                                                     :confirmation_numbers)
    end
  end

  context '#delete_malformed_claims' do
    it 'should return a count of deleted files and a filename' do
      expect(subject.delete_malformed_claims).to include(:filename, :count)
    end
  end

  context '#generate_spool_files' do
    it 'should return a list of generated files' do
      expect(subject.generate_spool_files).to be_a(Array)
    end
  end

  context '#upload_spool_files' do
    it 'should return a list of uploaded files' do
      expect(subject.upload_spool_files).to be_a(Array)
    end
  end

  context '#write_local_spool_file' do
    let(:region) { :eastern }
    let(:records) { [] }
    let(:dir) { Dir.mktmpdir }

    it 'should return a count, region, and filename' do
      expect(subject.write_local_spool_file(region, records, dir)).to include(
        :count,
        :region,
        :filename
      )
    end
  end

  context '#write_remote_spool_file' do
    let(:region) { :eastern }
    let(:records) { [] }
    let(:writer) { SFTPWriter::Local.new(Settings.edu.sftp, logger: Logger.new(STDOUT)) }

    it 'should return a count, region, and filename' do
      expect(subject.write_remote_spool_file(region, records, writer)).to include(
        :count,
        :region,
        :filename
      )
    end
  end

  context '#formatted_regional_data' do
    it 'should return a hash of regions and records' do
      expect(subject.formatted_regional_data).to be_a(Hash)
    end
  end

  context '#write_confirmation_numbers' do
    it 'should return the file written' do
      expect(subject.write_confirmation_numbers([])).to be_a(String)
    end
  end
end
