# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Message do
  context 'with valid attributes' do
    subject { described_class.new(params) }

    let(:params) { attributes_for :message }
    let(:other) { described_class.new(attributes_for(:message, sent_date: Time.current)) }

    it 'populates attributes' do
      expect(described_class.attribute_set.map(&:name)).to contain_exactly(:id, :category, :subject, :body,
                                                                           :attachment, :attachments, :sent_date,
                                                                           :sender_id, :sender_name, :recipient_id,
                                                                           :recipient_name, :read_receipt, :uploads,
                                                                           :triage_group_name, :proxy_sender_name)
      expect(subject.id).to eq(params[:id])
      expect(subject.category).to eq(params[:category])
      expect(subject.subject).to eq(params[:subject])
      expect(subject.body).to eq(params[:body])
      expect(subject.attachment).to eq(params[:attachment])
      expect(subject.sent_date).to eq(Time.parse(params[:sent_date]).utc)
      expect(subject.sender_id).to eq(params[:sender_id])
      expect(subject.sender_name).to eq(params[:sender_name])
      expect(subject.recipient_id).to eq(params[:recipient_id])
      expect(subject.recipient_name).to eq(params[:recipient_name])
      expect(subject.read_receipt).to eq(params[:read_receipt])
    end

    it 'sorts by sent_date DESC' do
      expect([subject, other].sort).to eq([other, subject])
    end

    describe 'when validating' do
      context 'message or draft' do
        it 'requires recipient_id' do
          expect(build(:message, recipient_id: '')).not_to be_valid
        end

        it 'requires body' do
          expect(build(:message, body: '')).not_to be_valid
        end

        it 'requires category' do
          expect(build(:message, category: '')).not_to be_valid
        end

        context 'file uploads' do
          let(:upload_class) { 'ActionDispatch::Http::UploadedFile' }
          let(:file1) { instance_double(upload_class, original_filename: 'file1.jpg', size: 1.megabytes) }
          let(:file2) { instance_double(upload_class, original_filename: 'file2.jpg', size: 2.megabytes) }
          let(:file3) { instance_double(upload_class, original_filename: 'file3.jpg', size: 1.megabytes) }
          let(:file4) { instance_double(upload_class, original_filename: 'file4.jpg', size: 4.megabytes) }
          let(:file5) { instance_double(upload_class, original_filename: 'file5.jpg', size: 6.1.megabytes) }

          it 'can validate file size with valid file sizes' do
            message = build(:message, uploads: [file1, file2, file3, file4])
            expect(message).to be_valid
          end

          it 'requires that there be no more than 4 uploads' do
            message = build(:message, uploads: [file1, file2, file3, file4, file5])
            expect(message).not_to be_valid
            expect(message.errors[:uploads]).to include('has too many files (maximum is 4 files)')
          end

          it 'requires that upload file size not exceed 6 MB for any one file' do
            message = build(:message, uploads: [file5])
            expect(message).not_to be_valid
            expect(message.errors[:base]).to include('The file5.jpg exceeds file size limit of 6.0 MB')
          end

          it 'require that total upload size not exceed 10 MB' do
            message = build(:message, uploads: [file2, file3, file4, file5])
            expect(message).not_to be_valid
            expect(message.errors[:base]).to include('Total size of uploads exceeds 10.0 MB')
          end
        end
      end

      context 'reply' do
        it 'requires recipient_id' do
          expect(build(:message, recipient_id: '').as_reply).to be_valid
        end

        it 'requires body' do
          expect(build(:message, body: '').as_reply).not_to be_valid
        end

        it 'requires category' do
          expect(build(:message, category: '').as_reply).to be_valid
        end
      end

      context 'drafts and replydraft' do
        let(:draft_with_message) { build(:message_draft, :with_message) }
        let(:draft) { build(:message_draft) }

        it 'drafts must not be tied to a message' do
          draft_with_message.valid?
          expect(draft_with_message).not_to be_valid
        end

        it 'reply drafts must be tied to a message' do
          expect(draft.as_reply).not_to be_valid
        end

        it 'requires a body' do
          expect(build(:message_draft, :with_message, body: '').as_reply).not_to be_valid
        end
      end
    end
  end
end
