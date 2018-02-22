# frozen_string_literal: true

require 'rails_helper'
require 'fileutils'
require 'workflow/task/pension_burial/upload'

RSpec.describe Workflow::Task::PensionBurial::Upload, run_at: '2017-01-10' do
  describe '#run' do
    let(:id) { 12 }
    let(:guid) { '123' }
    let(:form_id) { '99-9999EZ' }
    let(:claim_code) { 'V-TESTTEST' }
    let(:path) { File.join(Date.current.to_s, form_id, claim_code) }

    before(:all) do
      @file_path = Rails.root.join('spec', 'fixtures', 'files', 'doctors-note.pdf')
    end

    let(:attacher) do
      a = Shrine::Attacher.new(InternalAttachment.new, :file)
      a.assign(File.open(@file_path))
      a
    end

    let(:instance) do
      described_class.new({
                            id: id,
                            guid: guid,
                            form_id: form_id,
                            code: claim_code,
                            append_to_stamp: 'Confirmation=VETS-XX-1234'
                          }, internal: { file: attacher.read })
    end

    context 'with pension burial upload to api not enabled' do
      before do
        expect(Settings.pension_burial.upload).to receive(:enabled).and_return(false)
      end

      after do
        FileUtils.rm_rf(Rails.root.join('tmp', Settings.pension_burial.sftp.relative_path, path))
      end

      it 'passes the file off to SFTPWriter' do
        expect(PersistentAttachment).to receive(:find).with(id).and_return(double(update: true))
        write_path = File.join(path, '123-doctors-note.pdf')
        expect_any_instance_of(SFTPWriter::Local).to receive(:write)
          .with(File.read(@file_path), write_path)
          .and_return(nil)
        instance.run
      end
    end

    it 'uploads the file to the pension burial api' do
      expect(PersistentAttachment).to receive(:find).with(id).and_return(
        double(
          update: true,
          can_upload_to_api?: true
        )
      )

      VCR.use_cassette('pension_burial/upload', match_requests_on: [:body]) do
        instance.run
      end
    end
  end
end
