# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Preneeds::ReceiveApplication do
  context 'with valid attributes' do
    subject { described_class.new(params) }

    let(:params) { attributes_for(:receive_application) }

    it 'populates attributes', run_at: '2017-01-04 03:00:00 EDT' do
      name_map = described_class.attribute_set

      expect(name_map).to contain_exactly(
        :tracking_number, :return_code, :application_uuid, :return_description, :submitted_at
      )
      expect(subject.tracking_number).to eq(params[:tracking_number])
      expect(subject.return_code).to eq(params[:return_code])
      expect(subject.application_uuid).to eq(params[:application_uuid])
      expect(subject.return_description).to eq(params[:return_description])
      expect(subject.submitted_at).to eq(Time.zone.now)
    end
  end
end
