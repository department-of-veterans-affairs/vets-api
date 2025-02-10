# frozen_string_literal: true

require 'rails_helper'
require IvcChampva::Engine.root.join('spec', 'spec_helper.rb')

describe IvcChampva::PdfStamper do
  let(:data) { JSON.parse(File.read("modules/ivc_champva/spec/fixtures/form_json/#{test_payload}.json")) }
  let(:form) { "IvcChampva::#{test_payload.titleize.gsub(' ', '')}".constantize.new(data) }
  let(:template_path) { "modules/ivc_champva/templates/#{test_payload}.pdf" }
  let(:path) { 'tmp/pii_stuff.pdf' }

  describe '.stamp_pdf' do
    subject(:stamp_pdf) { described_class.stamp_pdf(path, form, 2) }

    let(:test_payload) { 'vha_10_10d' }

    before do
      FileUtils.copy(template_path, path)
      allow(described_class.send(:monitor)).to receive(:track_pdf_stamper_error)
    end

    after do
      File.delete(path) if File.exist?(path)
    end

    context 'when everything works fine' do
      before do
        allow(described_class).to receive(:stamp_signature).and_return(nil)
        allow(described_class).to receive(:stamp_auth_text).and_return(nil)
        allow(described_class).to receive(:stamp_submission_date).and_return(nil)
      end

      it 'does not raise any errors' do
        expect { stamp_pdf }.not_to raise_error
        expect(described_class).to have_received(:stamp_signature).with(path, form)
        expect(described_class).to have_received(:stamp_auth_text).with(path, 2)
        expect(described_class).to have_received(:stamp_submission_date).with(path, form.submission_date_stamps)
      end
    end

    context 'when the file at the stamped_template_path is missing' do
      before do
        File.delete(path) if File.exist?(path)
      end

      it 'raises an exception' do
        expect { stamp_pdf }.to raise_error(StandardError, "stamped template file does not exist: #{path}")
      end
    end

    context 'when stamping raises a PdfForms::PdftkError' do
      before do
        allow(described_class).to receive(:stamp_signature).and_return(nil)
        allow(described_class).to receive(:stamp_auth_text).and_raise(PdfForms::PdftkError, 'pdftk error ./some_pii.pdf')
        allow(described_class).to receive(:stamp_submission_date).and_return(nil)
      end

      it 'logs it with no PII and raises a PdfForms::PdftkError' do
        expect { stamp_pdf }.to raise_error(PdfForms::PdftkError, 'pdftk error ./some_pii.pdf')
        expect(described_class.monitor).to have_received(:track_pdf_stamper_error) do |_, message|
          expect(message).to include('PdftkError:')
          expect(message).not_to include('some_pii')
        end
      end
    end

    context 'when stamping raises a SystemCallError such as Errno::ENOENT' do
      before do
        allow(described_class).to receive(:stamp_signature).and_raise(Errno::ENOENT, 'pii_stuff.pdf')
        allow(described_class).to receive(:stamp_auth_text).and_return(nil)
        allow(described_class).to receive(:stamp_submission_date).and_return(nil)
      end

      it 'logs it with no PII and raises a Errno::ENOENT' do
        expect { stamp_pdf }.to raise_error(Errno::ENOENT, 'No such file or directory - pii_stuff.pdf')
        expect(described_class.monitor).to have_received(:track_pdf_stamper_error) do |_, message|
          expect(message).to include('SystemCallError:')
          expect(message).not_to include('pii_stuff')
        end
      end
    end

    context 'when stamping raises a StandardError' do
      before do
        allow(described_class).to receive(:stamp_signature).and_return(nil)
        allow(described_class).to receive(:stamp_auth_text).and_raise(StandardError, 'oh no')
        allow(described_class).to receive(:stamp_submission_date).and_return(nil)
      end

      it 'logs it with no PII and raises a PdfForms::PdftkError' do
        expect { stamp_pdf }.to raise_error(StandardError, 'oh no')
        expect(described_class.monitor).to have_received(:track_pdf_stamper_error) do |_, message|
          expect(message).to include('CatchAll:')
        end
      end
    end
  end

  describe '.stamp_signature' do
    subject(:stamp_signature) { described_class.stamp_signature(path, form) }

    before do
      allow(File).to receive(:size).and_return(1, 2)
    end

    context 'when no stamps are needed' do
      before do
        allow(described_class).to receive(:stamp).and_return(true)
        stamp_signature
      end

      let(:test_payload) { 'vha_10_7959c' }
      let(:stamps) { [] }

      it 'does not call :stamp' do
        expect(described_class).not_to have_received(:stamp)
      end
    end

    context 'when it is called with legitimate parameters' do
      before do
        allow(described_class).to receive(:multistamp).and_return(true)
        stamp_signature
      end

      let(:test_payload) { 'vha_10_10d' }
      let(:signature) { form.data['statement_of_truth_signature'] }
      let(:page_config) do
        [
          { type: :text, position: [40, 105] },
          { type: :new_page },
          { type: :new_page },
          { type: :new_page },
          { type: :new_page }
        ]
      end
    end
  end

  describe '.multistamp' do
    subject(:multistamp) { described_class.multistamp(stamped_template_path, signature_text, page_configuration) }

    let(:stamped_template_path) { 'path/to/stamped_template.pdf' }
    let(:signature_text) { 'Signature Text' }
    let(:page_configuration) do
      [
        { type: :text, position: [40, 105] },
        { type: :new_page },
        { type: :new_page },
        { type: :new_page },
        { type: :new_page }
      ]
    end

    context 'when an error occurs during stamping' do
      before do
        allow(Prawn::Document).to receive(:generate).and_yield(pdf)
        allow(pdf).to receive(:draw_text).and_raise(StandardError, 'error drawing text')
        allow(pdf).to receive(:start_new_page)
        allow(Common::FileHelpers).to receive(:random_file_path).and_return('tmp/000033337777BBBB111144448888CCCC')
        allow(Common::FileHelpers).to receive(:delete_file_if_exists)
      end

      let(:pdf) { instance_double(Prawn::Document) }

      it 'attempts to delete the temporary stamping file' do
        expect(Common::FileHelpers).to receive(:delete_file_if_exists).with('tmp/000033337777BBBB111144448888CCCC')
        expect { multistamp }.to raise_error(StandardError, 'error drawing text')
      end

      context 'when deleting the temporary stamping file fails' do
        before do
          allow(Common::FileHelpers).to receive(:delete_file_if_exists).and_raise(Errno::ENOENT, 'tmp/000033337777BBBB111144448888CCCC')
        end

        it 'proceeds gracefully' do
          expect { multistamp }.to raise_error(StandardError, 'error drawing text')
        end
      end
    end
  end

  describe '.stamp' do

  end

  describe '.perform_multistamp' do

  end

  describe '.verify' do
    subject(:verify) { described_class.verify('template_path') { double } }

    before { allow(File).to receive(:size).and_return(orig_size, stamped_size) }

    describe 'when verifying a stamp' do
      let(:orig_size) { 10_000 }

      context 'when the stamped file size is larger than the original' do
        let(:stamped_size) { orig_size + 1 }

        it 'succeeds' do
          expect { verify }.not_to raise_error
        end
      end

      context 'when the stamped file size is the same as the original' do
        let(:stamped_size) { orig_size }

        it 'raises an error message' do
          expect { verify }.to raise_error(
            'An error occurred while verifying stamp: The PDF remained unchanged upon stamping.'
          )
        end
      end

      context 'when the stamped file size is less than the original' do
        let(:stamped_size) { orig_size - 1 }

        it 'raises an error message' do
          expect { verify }.to raise_error(
            'An error occurred while verifying stamp: The PDF remained unchanged upon stamping.'
          )
        end
      end
    end
  end

  describe '.verified_multistamp' do
    subject(:verified_multistamp) { described_class.verified_multistamp(path, signature_text, config) }

    before { allow(described_class).to receive(:verify).and_return(true) }

    context 'when signature_text is blank' do
      let(:path) { nil }
      let(:signature_text) { nil }
      let(:config) { nil }

      it 'raises an error' do
        expect { verified_multistamp }.to raise_error('The provided stamp content was empty.')
      end
    end
  end
end
