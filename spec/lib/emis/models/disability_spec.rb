# frozen_string_literal: true
require 'rails_helper'

describe EMIS::Models::Disability do
  %w(disability_percent pay_amount).each do |attr|
    method_name = "get_#{attr}"

    describe "##{method_name}" do
      it 'should return 0 if the field is nil' do
        expect(
          described_class.new(
            {
              disability_percent: 50,
              pay_amount: 1
            }.merge(attr.to_sym => nil)
          ).public_send(method_name)
        ).to eq(0)
      end
    end
  end
end
