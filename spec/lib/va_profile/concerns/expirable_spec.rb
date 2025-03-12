# frozen_string_literal: true

require 'rails_helper'
require 'va_profile/concerns/expirable'

class TestModel < VAProfile::Models::Base
  include ActiveModel::Validations
  include VAProfile::Concerns::Expirable

  attribute :effective_end_date, Common::ISO8601Time
end

describe VAProfile::Concerns::Expirable do
  before { Timecop.freeze }
  after { Timecop.return }

  describe '#effective_end_date_has_passed' do
    it 'invalidates model if effective_end_date is in the future' do
      test_model = TestModel.new(effective_end_date: 1.minute.from_now.iso8601)
      expect(test_model.valid?).to be(false)
    end

    it 'does not invalidate model if effective_end_date is not in the future' do
      test_model = TestModel.new(effective_end_date: Time.current.iso8601)
      expect(test_model.valid?).to be(true)
    end

    it 'does not invalidate model if effective_end_date is nil' do
      test_model = TestModel.new
      expect(test_model.valid?).to be(true)
    end
  end
end
