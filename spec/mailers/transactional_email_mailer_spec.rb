# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TransactionalEmailMailer, type: [:mailer] do
  subject do
    described_class.build(email, google_analytics_client_id).deliver_now
  end

  let(:email) { 'foo@example.com' }
  let(:google_analytics_client_id) { '123456543' }

  describe 'as a parent class' do
    it 'cannot be called directly due to missing constants' do
      expect { subject }.to raise_error(NameError)
    end

    TransactionalEmailMailer.descendants.each do |mailer|
      it "requires #{mailer.name} subclass to define required constants" do
        expect(mailer::SUBJECT).to be_present
        expect(mailer::GA_CAMPAIGN_NAME).to be_present
        expect(mailer::GA_DOCUMENT_PATH).to be_present
        expect(mailer::GA_LABEL).to be_present
        expect(mailer::TEMPLATE).to be_present
      end
    end
  end

  describe 'helper methods' do
    context '#full_name' do
      subject { described_class.full_name(name) }

      let(:name) { OpenStruct.new(first: 'Mark', last: 'Olson') }

      context 'with no middle name' do
        it 'does not have extra spaces' do
          expect(subject).to eq('Mark Olson')
        end
      end

      context 'with a middle name' do
        it 'is included' do
          name.middle = 'Middle'
          expect(subject).to eq 'Mark Middle Olson'
        end
      end
    end
  end
end
