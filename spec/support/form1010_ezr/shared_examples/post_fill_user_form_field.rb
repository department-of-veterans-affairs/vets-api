# frozen_string_literal: true

require 'rails_helper'

shared_examples_for 'post-fill user form field' do
  subject { described_class.new(current_user) }

  context 'when the field is already present in the form' do
    let(:parsed_form) { _parsed_form }

    it 'returns nil' do
      expect(subject.send(klass_method.to_sym, parsed_form)).to eq(nil)
    end
  end

  context 'when the field is not present, but the field is present in the user session' do
    let(:parsed_form) { {} }

    before do
      allow(StatsD).to receive(:increment)
    end

    it "increments StatsD, adds/updates the form field to be equal to the current_user's data, " \
       'and returns the parsed form' do
      expect(StatsD).to receive(:increment).with("api.1010ezr.#{statsd_increment_name}")
      expect(service.send(klass_method.to_sym, parsed_form)).to eq(
        { user_field => user_data }
      )
    end
  end
end
