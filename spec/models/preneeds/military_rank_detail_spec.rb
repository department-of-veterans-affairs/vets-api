# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Preneeds::MilitaryRankDetail do
  context 'with valid attributes' do
    subject { described_class.new(params) }

    let(:params) { attributes_for :military_rank_detail }
    let(:other) { build :military_rank_detail }

    it 'populates attributes' do
      expect(
        described_class.attribute_set.map(&:name)
      ).to contain_exactly(:branch_of_service_code, :rank_code, :rank_descr)

      expect(subject.branch_of_service_code).to eq(params[:branch_of_service_code])
      expect(subject.rank_code).to eq(params[:rank_code])
      expect(subject.rank_descr).to eq(params[:rank_descr])
      expect(subject.id).to eq(params[:branch_of_service_code] + ':' + params[:rank_code])
    end
  end
end
