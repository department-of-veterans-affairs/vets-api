# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GIBillFeedback, type: :model do
  let(:gi_bill_feedback) { build(:gi_bill_feedback) }

  describe '#find' do
    it 'is able to find created models' do
      gi_bill_feedback.save!
      guid = gi_bill_feedback.guid

      expect(described_class.find(guid).guid).to eq(guid)
    end
  end

  describe '#remove_malformed_options' do
    it 'removes malformed options' do
      expect(gi_bill_feedback.send(:remove_malformed_options,
                                   'Post-9/11 Ch 33' => true,
                                   'post9::11 ch 33' => true,
                                   'MGIB-AD Ch 30' => true)).to eq(
                                     'Post-9/11 Ch 33' => true, 'MGIB-AD Ch 30' => true
                                   )
    end
  end

  describe '#transform_malformed_options' do
    it 'transforms malformed options' do
      expect(gi_bill_feedback.send(:transform_malformed_options,
                                   'post9::11 ch 33' => true,
                                   'MGIB-AD Ch 30' => true,
                                   'chapter1606' => true)).to eq(
                                     'Post-9/11 Ch 33' => true, 'MGIB-AD Ch 30' => true,
                                     'MGIB-SR Ch 1606' => true
                                   )
    end
  end

  describe '#transform_form' do
    before do
      gi_bill_feedback.user = create(:user, icn: nil, sec_id: nil)
    end

    context 'with no user' do
      let(:user) { nil }

      it 'transforms the form' do
        form = gi_bill_feedback.parsed_form
        gi_bill_feedback.form = form.to_json
        gi_bill_feedback.send(:remove_instance_variable, :@parsed_form)
        expect(gi_bill_feedback.transform_form).to eq(get_fixture('gibft/transform_form_no_user'))
      end
    end

    context 'with a user' do
      let(:user) { create(:user) }

      it 'transforms the form to the right format' do
        expect(gi_bill_feedback.transform_form).to eq(get_fixture('gibft/transform_form'))
      end

      context 'with malformed options' do
        before do
          form = gi_bill_feedback.parsed_form
          form['educationDetails']['programs'] = {
            'mGIBAd ch 30' => true
          }
          gi_bill_feedback.form = form.to_json
          gi_bill_feedback.send(:remove_instance_variable, :@parsed_form)
        end

        it 'transforms the malformed options' do
          expect(gi_bill_feedback.transform_form).to eq(get_fixture('gibft/transform_form'))
        end
      end
    end
  end

  describe '#create_submission_job' do
    it 'does not pass in the user if form is anonymous' do
      form = gi_bill_feedback.parsed_form
      form['onBehalfOf'] = 'Anonymous'
      user = create(:user)
      gi_bill_feedback.form = form.to_json
      gi_bill_feedback.instance_variable_set(:@parsed_form, nil)
      gi_bill_feedback.user = user

      expect(GIBillFeedbackSubmissionJob).to receive(:perform_async).with(gi_bill_feedback.id, form.to_json, nil)
      gi_bill_feedback.send(:create_submission_job)
    end
  end
end
