# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EducationForm::Forms::VA10203 do
  subject { described_class.new(education_benefits_claim) }

  let(:education_benefits_claim) { build(:va10203).education_benefits_claim }

  %w[kitchen_sink minimal].each do |test_application|
    test_spool_file('10203', test_application)
  end

  describe '#after_submit' do
    context 'authorized' do
      before do
        expect(user).to receive(:authorize).with(:evss, :access?).and_return(true).at_least(:once)
        expect(user.authorize(:evss, :access?)).to eq(true)
      end

      context 'sco email sent is false' do
        it 'when no remaining entitlement is present' do
          allow_any_instance_of(Faraday::Connection).to receive(:get).and_raise(Faraday::TimeoutError)

          subject.after_submit(user)

          expect(subject.parsed_form['scoEmailSent']).to eq(false)
        end

        # it 'when no facility code is present' do
        # end
        #
        # it 'when FeatureFlipper.send_email? is false' do
        # end
        #
        # it 'when more than six months of entitlement remaining' do
        # end
        #
        # it 'when institution is blank' do
        # end
        #
        # it 'when school has changed' do
        # end
        #
        # it 'when neither a primary or secondary sco with an email address is found' do
        # end
      end
    end

    context 'unauthorized' do
      before do
        expect(user).to receive(:authorize).with(:evss, :access?).and_return(false).at_least(:once)
        expect(user.authorize(:evss, :access?)).to eq(false)
      end

      it 'sco email sent is false' do
        subject.after_submit(user)
        expect(subject.parsed_form['scoEmailSent']).to eq(false)
      end
    end
  end
end
