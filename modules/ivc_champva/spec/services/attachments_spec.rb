# frozen_string_literal: true

require 'rails_helper'

class TestClass
  include IvcChampva::Attachments
  attr_accessor :form_id, :uuid, :data

  def initialize(form_id, uuid, data)
    @form_id = form_id
    @uuid = uuid
    @data = data
  end
end

RSpec.describe IvcChampva::Attachments do
  # Mocking a class to include the Attachments module
  let(:form_id) { 'vha_10_7959c' }
  let(:uuid) { 'f4ae6102-7f05-485a-948c-c0d9ef028983' }
  let(:file_path) { 'tmp/f4ae6102-7f05-485a-948c-c0d9ef028983_vha_10_7959c-tmp.pdf' }
  let(:data) { { 'supporting_docs' => [{ 'confirmation_codes' => 'doc1' }, { 'confirmation_codes' => 'doc2' }] } }
  let(:test_instance) { TestClass.new(form_id, uuid, data) }

  describe '#handle_attachments' do
    context 'when there are supporting documents' do
      it 'renames and processes attachments' do
        expect(test_instance).to receive(:get_attachments).and_return(['attachment1.pdf', 'attachment2.png'])
        expect(File).to receive(:rename).with('attachment1.pdf', "tmp/#{uuid}_#{form_id}_supporting_doc-0.pdf")
        expect(File).to receive(:rename).with('attachment2.png', "tmp/#{uuid}_#{form_id}_supporting_doc-1.pdf")

        result = test_instance.handle_attachments(file_path)
        expect(result).to contain_exactly("tmp/#{uuid}_#{form_id}-tmp.pdf",
                                          "tmp/#{uuid}_#{form_id}_supporting_doc-0.pdf",
                                          "tmp/#{uuid}_#{form_id}_supporting_doc-1.pdf")
      end
    end

    context 'when there are multiple PDFs needed' do
      it 'generates an additional pdf for 10-10D' do
        stub_const('IvcChampva::VHA1010d::ADDITIONAL_PDF_KEY', 'applicants')
        stub_const('IvcChampva::VHA1010d::ADDITIONAL_PDF_COUNT', 3)

        fixture_path = Rails.root.join('modules', 'ivc_champva', 'spec', 'fixtures', 'form_json', 'vha_10_10d.json')
        data = JSON.parse(fixture_path.read)
        form = IvcChampva::VHA1010d.new(data)

        file_paths = form.handle_attachments('modules/ivc_champva/templates/vha_10_10d.pdf')

        expect(file_paths.count).to eq(2)
        expect(file_paths[1]).to include('additional')
      end

      it 'generates an additional pdf for 10-10D upon retry' do
        stub_const('IvcChampva::VHA1010d::ADDITIONAL_PDF_KEY', 'applicants')
        stub_const('IvcChampva::VHA1010d::ADDITIONAL_PDF_COUNT', 3)

        fixture_path = Rails.root.join('modules', 'ivc_champva', 'spec', 'fixtures', 'form_json', 'vha_10_10d.json')
        data = JSON.parse(fixture_path.read)

        file_paths = []
        2.times do
          form = IvcChampva::VHA1010d.new(data)
          file_paths.concat form.handle_attachments('modules/ivc_champva/templates/vha_10_10d.pdf')
        end

        # We should have two 10-10d paths and two additional-applicants PDF paths
        expect(file_paths.count).to eq(4)
        expect(file_paths.grep(/additional/).count).to eq(2)
      end
    end

    context 'when there are no supporting documents' do
      before do
        allow(test_instance).to receive(:get_attachments).and_return([])
      end

      it 'renames the file without processing attachments' do
        result = test_instance.handle_attachments(file_path)
        expect(result).to eq(["tmp/#{uuid}_#{form_id}-tmp.pdf"])
      end
    end
  end

  describe '#handle_attachment_errors' do
    context 'when processing one of multiple attachments fails' do
      it 'processes the rest of the attachments then throw an error' do
        expect(test_instance).to receive(:get_attachments).and_return(['attachmentA.pdf', 'attachmentB.png',
                                                                       'attachmentC.jpg', 'attachmentD.jpg'])
        expect(File).to receive(:rename).with('attachmentA.pdf', "tmp/#{uuid}_#{form_id}_supporting_doc-0.pdf")
        expect(File).to receive(:rename).with('attachmentB.png', "tmp/#{uuid}_#{form_id}_supporting_doc-1.pdf")
                                        .and_raise(StandardError.new('Processing failed'))
        expect(File).to receive(:rename).with('attachmentC.jpg', "tmp/#{uuid}_#{form_id}_supporting_doc-2.pdf")
        expect(File).to receive(:rename).with('attachmentD.jpg', "tmp/#{uuid}_#{form_id}_supporting_doc-3.pdf")

        expected_error_message = 'Unable to process all attachments: '
        expected_error_message += 'Error processing attachment at index 1: Processing failed'
        expect do
          test_instance.handle_attachments(file_path)
        end.to raise_error(StandardError, expected_error_message)
      end
    end

    context 'when processing two of multiple attachments fails' do
      it 'processes the rest of the attachments then throw an error with both failure messages' do
        expect(test_instance).to receive(:get_attachments).and_return(['attachmentA.pdf', 'attachmentB.png',
                                                                       'attachmentC.jpg', 'attachmentD.jpg'])
        expect(File).to receive(:rename).with('attachmentA.pdf', "tmp/#{uuid}_#{form_id}_supporting_doc-0.pdf")
        expect(File).to receive(:rename).with('attachmentB.png', "tmp/#{uuid}_#{form_id}_supporting_doc-1.pdf")
                                        .and_raise(StandardError.new('Processing failed'))
        expect(File).to receive(:rename).with('attachmentC.jpg', "tmp/#{uuid}_#{form_id}_supporting_doc-2.pdf")
                                        .and_raise(StandardError.new('Processing failed'))
        expect(File).to receive(:rename).with('attachmentD.jpg', "tmp/#{uuid}_#{form_id}_supporting_doc-3.pdf")

        expected_error_message = 'Unable to process all attachments: '
        expected_error_message += 'Error processing attachment at index 1: Processing failed, '
        expected_error_message += 'Error processing attachment at index 2: Processing failed'
        expect do
          test_instance.handle_attachments(file_path)
        end.to raise_error(StandardError, expected_error_message)
      end
    end

    context 'when a file is not found' do
      it 'throws an error with hard coded details' do
        expect(test_instance).to receive(:get_attachments).and_return(['attachmentA.pdf'])
        expect(FileUtils).to receive(:mv).with('attachmentA.pdf', "tmp/#{uuid}_#{form_id}_supporting_doc-0.pdf")
                                         .and_raise(Errno::ENOENT.new)

        expected_error_message = 'Unable to process all attachments: '
        expected_error_message += 'Error processing attachment at index 0: ENOENT No such file or directory'
        expect do
          test_instance.handle_attachments(file_path)
        end.to raise_error(StandardError, expected_error_message)
      end
    end

    context 'when an unanticipated low-level platform-dependent error occurs' do
      it 'throws an error with hard coded details and the decoded error number when available' do
        expect(test_instance).to receive(:get_attachments).and_return(['attachmentA.pdf', 'attachmentB.png'])
        expect(File).to receive(:rename).with('attachmentA.pdf', "tmp/#{uuid}_#{form_id}_supporting_doc-0.pdf")
                                        .and_raise(SystemCallError.new('message with PII', -1))
        expect(File).to receive(:rename).with('attachmentB.png', "tmp/#{uuid}_#{form_id}_supporting_doc-1.pdf")
                                        .and_raise(Errno::EEXIST)

        expected_error_message = 'Unable to process all attachments: '
        expected_error_message += 'Error processing attachment at index 0: SystemCallError Unknown -1, '
        expected_error_message += 'Error processing attachment at index 1: SystemCallError EEXIST'
        expect do
          test_instance.handle_attachments(file_path)
        end.to raise_error(StandardError, expected_error_message)
      end
    end
  end
end
