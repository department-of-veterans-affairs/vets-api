# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EducationForm::EducationFacility do
  let(:education_benefits_claim) { build(:education_benefits_claim) }
  let(:eastern_address) do
    OpenStruct.new(country: 'USA', state: 'DE')
  end
  let(:central_address) do
    OpenStruct.new(country: 'USA', state: 'IL')
  end
  let(:western_address) do
    OpenStruct.new(country: 'USA', state: 'CA')
  end

  def school(data)
    OpenStruct.new(address: data)
  end

  describe '#routing_address' do
    let(:form) { OpenStruct.new }
    context '22-1990' do
      it 'uses educationProgram over veteranAddress' do
        form.educationProgram = school(eastern_address)
        form.veteranAddress = western_address
        expect(described_class.routing_address(form, form_type: '1990').state).to eq(eastern_address.state)
      end
      it 'uses veteranAddress when no school address is given' do
        form.veteranAddress = western_address
        expect(described_class.routing_address(form, form_type: '1990').state).to eq(western_address.state)
      end
    end
    context '22-1990N' do
      let(:form) { OpenStruct.new(veteranAddress: western_address) }
      it 'uses educationProgram over veteranAddress' do
        form.educationProgram = school(central_address)
        expect(described_class.routing_address(form, form_type: '1990n').state).to eq(central_address.state)
      end
      it 'uses veteranAddress when no school address is given' do
        expect(described_class.routing_address(form, form_type: '1990n').state).to eq(western_address.state)
      end
    end
    context '22-1995' do
      let(:form) { OpenStruct.new(veteranAddress: western_address) }
      it 'uses newSchool over relativeAddress' do
        form.newSchool = school(central_address)
        expect(described_class.routing_address(form, form_type: '1995').state).to eq(central_address.state)
      end
      it 'uses veteranAddress when no school address is given' do
        expect(described_class.routing_address(form, form_type: '1995').state).to eq(western_address.state)
      end
    end
    %w[1990E 5490 5495].each do |form_type|
      context "22-#{form_type}" do
        let(:form) { OpenStruct.new(relativeAddress: western_address) }
        it 'uses educationProgram over relativeAddress' do
          form.educationProgram = school(central_address)
          expect(described_class.routing_address(form, form_type: form_type).state).to eq(central_address.state)
        end
        it 'uses relativeAddress when no educationProgram address is given' do
          expect(described_class.routing_address(form, form_type: form_type).state).to eq(western_address.state)
        end
      end
    end
  end

  describe '#regional_office_for' do
    {
      eastern: ['VA', "Eastern Region\nVA Regional Office\nP.O. Box 4616\nBuffalo, NY 14240-4616"],
      # rubocop:disable Metrics/LineLength
      central: ['CO', "Central Region\nVA Regional Office\n9770 Page Avenue\nSuite 101 Education\nSt. Louis, MO 63132-1502"],
      # rubocop:enable Metrics/LineLength
      western: ['AK', "Western Region\nVA Regional Office\nP.O. Box 8888\nMuskogee, OK 74402-8888"]
    }.each do |region, region_data|
      context "with a #{region} address" do
        before do
          new_form = education_benefits_claim.parsed_form
          new_form['educationProgram']['address']['state'] = region_data[0]
          education_benefits_claim.saved_claim.form = new_form.to_json
        end

        it 'should return the right address' do
          expect(described_class.regional_office_for(education_benefits_claim)).to eq(region_data[1])
        end
      end
    end
  end
end
