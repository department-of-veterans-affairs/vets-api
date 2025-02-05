# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RepresentationManagement::PowerOfAttorneyRequestEmailData, type: :model do
  describe 'validations' do
    subject { described_class.new }

    it { expect(subject).to validate_presence_of(:pdf_data) }
  end

  # describe 'methods' do
  #   # Construct the data object here
  #   subject { described_class.new(pdf_data: pdf_data) }

  #   it 'returns the correct first name' do
  #     expect(subject.first_name).to eq('John')
  #   end

  #   it 'returns the correct last name' do
  #     expect(subject.last_name).to eq('Doe')
  #   end

  #   it 'returns the correct submit date' do
  #     expect(subject.submit_date).to eq(Time.zone.now.in_time_zone('Eastern Time (US & Canada)').strftime('%B %d, %Y'))
  #   end

  #   it 'returns the correct submit time' do
  #     expect(subject.submit_time).to eq(Time.zone.now.in_time_zone('Eastern Time (US & Canada)').strftime('%I:%M %p'))
  #   end

  #   it 'returns the correct expiration date' do
  #     expect(subject.expiration_date).to eq((Time.zone.now.in_time_zone('Eastern Time (US & Canada)') + 60.days).strftime('%B %d, %Y'))
  #   end

  #   it 'returns the correct expiration time' do
  #     expect(subject.expiration_time).to eq(Time.zone.now.in_time_zone('Eastern Time (US & Canada)').strftime('%I:%M %p'))
  #   end

  #   it 'returns the correct representative name' do
  #     expect(subject.representative_name).to eq('Rep Name')
  #   end
  # end
end
