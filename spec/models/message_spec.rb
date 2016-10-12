# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Message do
  context 'with valid attributes' do
    subject { described_class.new(params) }

    let(:params) { attributes_for :message }
    let(:other) { described_class.new(attributes_for(:message)) }

    it 'populates attributes' do
      expect(described_class.attribute_set.map(&:name)).to contain_exactly(:id, :category, :subject, :body,
                                                                           :attachment, :attachments, :sent_date,
                                                                           :sender_id, :sender_name, :recipient_id,
                                                                           :recipient_name, :read_receipt, :uploads)
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

    it 'can be compared by id' do
      expect(subject <=> other).to eq(-1)
      expect(other <=> subject).to eq(1)
    end

    describe 'when validating' do
      it 'requires recipient_id' do
        expect(build(:message, recipient_id: '')).to_not be_valid
      end

      it 'requires body' do
        expect(build(:message, body: '')).to_not be_valid
      end

      it 'requires category' do
        expect(build(:message, category: '')).to_not be_valid
      end
    end
  end
end
