# frozen_string_literal: true

require 'rails_helper'
require 'shrine/plugins/validate_pdf_page_count'

describe Shrine::Plugins::ValidatePdfPageCount do
  describe '#validate_pdf_page_count' do
    let(:one_pager) { Rails.root.join('spec', 'fixtures', 'files', 'doctors-note.pdf') }
    let(:two_pager) { Rails.root.join('spec', 'fixtures', 'files', 'lgy_file.pdf') }

    let(:klass) do
      Class.new do
        include Shrine::Plugins::ValidatePdfPageCount::AttacherMethods
        def get
          raise "shouldn't be called"
        end

        def record
          self
        end

        def warnings
          @warnings ||= []
        end
      end
    end

    let(:instance) { klass.new }

    let(:attachment) do
      instance_double(Shrine::UploadedFile, download: File.open(file), mime_type: 'application/pdf')
    end

    before do
      allow(instance).to receive(:get).and_return(attachment)
    end

    context 'with correct number of pages' do
      let(:file) { two_pager }

      it 'does not add a warning' do
        expect { instance.validate_pdf_page_count(max_pages: 3, min_pages: 1) }.not_to(
          change do
            instance.warnings.count
          end
        )
      end
    end

    context 'with too few pages' do
      let(:file) { one_pager }

      it 'adds a warning' do
        expect { instance.validate_pdf_page_count(max_pages: 3, min_pages: 2) }.to change {
                                                                                     instance.warnings.count
                                                                                   }.from(0).to(1)
      end
    end

    context 'with too many pages' do
      let(:file) { two_pager }

      it 'adds a warning' do
        expect { instance.validate_pdf_page_count(max_pages: 1, min_pages: 1) }.to change {
                                                                                     instance.warnings.count
                                                                                   }.from(0).to(1)
      end
    end
  end
end
