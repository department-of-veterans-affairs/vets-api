# frozen_string_literal: true

require 'rails_helper'
require 'evss/disability_compensation_form/data_translation'

describe EVSS::DisabilityCompensationForm::DataTranslation do
  let(:form_content) { JSON.parse(File.read('spec/support/disability_compensation_form/front_end_submission.json')) }
  let(:evss_json) { File.read 'spec/support/disability_compensation_form/evss_submission.json' }
  let(:user) { build(:disabilities_compensation_user) }

  before do
    User.create(user)
  end

  subject { described_class.new(user, form_content) }

  describe '#convert' do
    before do
      create(:in_progress_form, form_id: VA526ez::FORM_ID, user_uuid: user.uuid)
      allow_any_instance_of(EMISRedis::MilitaryInformation).to receive(:service_episodes_by_date).and_return([])
    end

    it 'should return correctly formatted json to send to EVSS' do
      VCR.use_cassette('evss/ppiu/payment_information') do
        VCR.use_cassette('evss/intent_to_file/active_compensation') do
          expect(JSON.parse(subject.convert)).to eq JSON.parse(evss_json)
        end
      end
    end
  end
end
