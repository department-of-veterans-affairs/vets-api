# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GIBillFeedback, type: :model do
  let(:gi_bill_feedback) { build(:gi_bill_feedback) }

  describe '#find' do
    it 'should be able to find created models' do
      gi_bill_feedback.save!
      guid = gi_bill_feedback.guid

      expect(described_class.find(guid).guid).to eq(guid)
    end
  end

  describe '#transform_form' do
    it 'should transform the form to the right format' do
      gi_bill_feedback.user = create(:user)
      VCR.use_cassette('gi_client/gets_the_institution_details_with_addr') do
        expect(gi_bill_feedback.transform_form).to eq(get_fixture('gibft/transform_form'))
      end
    end
  end

  describe '#create_submission_job' do
    it 'should not pass in the user if form is anonymous' do
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
