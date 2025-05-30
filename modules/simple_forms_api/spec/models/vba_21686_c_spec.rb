# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/shared_examples_for_base_form'

RSpec.describe SimpleFormsApi::VBA21686C do
  subject { described_class.new({}) }

  let(:time) { DateTime.new(2025, 6, 2, 12) }

  describe '#submission_date_stamps' do
    it 'prepares an array for filling in the date box stamp on 21-686c form' do
      Timecop.freeze(time) do
        expect(subject.submission_date_stamps(time)).to eq(
          [
            { coords: [395, 710],
              text: 'Submitted Via: Authorized Representative', page: 0, font_size: 10 },
            { coords: [395, 695], text: 'Portal on VA.gov', page: 0,
              font_size: 10 },
            { coords: [395, 680], text: '12:00 PM UTC 2025-06-02',
              page: 0, font_size: 10 },
            { coords: [395, 665],
              text: 'Signee signed with an identity-verified', page: 0, font_size: 10 },
            { coords: [395, 650], text: 'account.', page: 0,
              font_size: 10 }
          ]
        )
      end
    end
  end
end
