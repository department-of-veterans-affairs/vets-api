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
  let(:form_id) { '123' }
  let(:uuid) { 'abc123' }
  let(:data) { { 'supporting_docs' => [{ 'confirmation_codes' => 'doc1' }, { 'confirmation_codes' => 'doc2' }] } }
  let(:test_instance) { TestClass.new(form_id, uuid, data) }

  describe '#handle_attachments' do
    context 'when there are supporting documents' do
      let(:file_path) { 'tmp/123-tmp.pdf' }

      it 'renames and processes attachments' do
        expect(File).to receive(:rename).with(file_path, "tmp/#{uuid}_#{form_id}-tmp.pdf")
        expect(test_instance).to receive(:get_attachments).and_return(['attachment1.pdf', 'attachment2.pdf'])
        expect(File).to receive(:rename).with('attachment1.pdf', "./#{uuid}_#{form_id}-tmp1.pdf")
        expect(File).to receive(:rename).with('attachment2.pdf', "./#{uuid}_#{form_id}-tmp2.pdf")

        result = test_instance.handle_attachments(file_path)
        expect(result).to match_array(
          ["tmp/#{uuid}_#{form_id}-tmp.pdf", "./#{uuid}_#{form_id}-tmp1.pdf", "./#{uuid}_#{form_id}-tmp2.pdf"]
        )
      end
    end

    context 'when there are no supporting documents' do
      let(:file_path) { 'tmp/123-tmp.pdf' }

      before do
        allow(test_instance).to receive(:get_attachments).and_return([])
      end

      it 'renames the file without processing attachments' do
        expect(File).to receive(:rename).with(file_path, "tmp/#{uuid}_#{form_id}-tmp.pdf")

        result = test_instance.handle_attachments(file_path)
        expect(result).to eq(["tmp/#{uuid}_#{form_id}-tmp.pdf"])
      end
    end
  end
end
