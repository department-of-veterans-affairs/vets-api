# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Preneeds::MilitaryRank do
  context 'with valid attributes' do
    subject { described_class.new(params) }

    let(:params) { attributes_for :military_rank }
    let(:other) { build :military_rank }

    it 'populates attributes' do
      expect(described_class.attribute_set.map(&:name)).to contain_exactly(
        :branch_of_service_cd, :activated_one_date, :activated_two_date, :activated_three_date,
        :deactivated_one_date, :deactivated_two_date, :deactivated_three_date, :officer_ind, :military_rank_detail
      )

      expect(subject.branch_of_service_cd).to eq(params[:branch_of_service_cd])
      expect(subject.activated_one_date).to eq(params[:activated_one_date])
      expect(subject.activated_two_date).to eq(params[:activated_two_date])
      expect(subject.activated_three_date).to eq(params[:activated_three_date])
      expect(subject.deactivated_one_date).to eq(params[:deactivated_one_date])
      expect(subject.deactivated_two_date).to eq(params[:deactivated_two_date])
      expect(subject.deactivated_three_date).to eq(params[:deactivated_three_date])
      expect(subject.officer_ind).to eq(params[:officer_ind])
      expect(subject.military_rank_detail.attributes).to eq(params[:military_rank_detail])
    end

    it 'can be compared by id' do
      expect(subject <=> other).to eq(-1)
      expect(other <=> subject).to eq(1)
    end
  end
end
