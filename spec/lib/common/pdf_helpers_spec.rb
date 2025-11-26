# frozen_string_literal: true

require 'rails_helper'

require 'common/pdf_helpers'

describe Common::PdfHelpers do
  describe '#unlock_pdf' do
    let(:file_name) { 'aes256_password.pdf' }
    let(:bad_password) { 'bad_pw_test' }
    let(:password) { 'test' }

    context 'when provided password is incorrect' do
      it 'logs a message to sentry' do
        error_message = nil
        allow(subject).to receive(:log_message_to_sentry) do |message, _level| # rubocop:disable RSpec/SubjectStub
          error_message = message
        end

        input_file = Rack::Test::UploadedFile.new('spec/fixtures/files/aes256_password.pdf', 'application/pdf')
        output_file = Tempfile.new(['encrypted_attachment', '.pdf'])

        expect { subject.unlock_pdf(input_file, bad_password, output_file) }
          .to raise_error(Common::Exceptions::UnprocessableEntity)

        expect(error_message).to be 'Invalid password specified'
      end
    end

    context 'when provided password is correct' do
      it 'does not log a message to sentry' do
        input_file = Rack::Test::UploadedFile.new('spec/fixtures/files/aes256_password.pdf', 'application/pdf')
        output_file = Tempfile.new(['encrypted_attachment', '.pdf'])

        expect(subject).not_to receive(:log_message_to_sentry) # rubocop:disable RSpec/SubjectStub
        expect { subject.unlock_pdf(input_file, password, output_file) }
          .not_to raise_error
      end
    end
  end
end
