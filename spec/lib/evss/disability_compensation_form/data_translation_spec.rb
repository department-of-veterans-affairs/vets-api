# frozen_string_literal: true

require 'rails_helper'
require 'evss/disability_compensation_form/data_translation'

describe EVSS::DisabilityCompensationForm::DataTranslation do
  let(:form_content) { JSON.parse(File.read 'spec/support/disability_compensation_form/front_end_submission.json') }
  let(:evss_json) { File.read 'spec/support/disability_compensation_form/evss_submission.json' }

  subject { described_class.new(form_content) }

  describe '#convert' do
    it 'should return correctly formatted json to send to EVSS' do
      expect(subject.convert).to eq evss_json
    end
  end
end
