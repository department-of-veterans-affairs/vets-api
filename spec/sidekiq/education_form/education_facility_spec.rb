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
          expect(described_class.routing_address(form, form_type:).state).to eq(central_address.state)
        end

        it 'uses relativeAddress when no educationProgram address is given' do
          expect(described_class.routing_address(form, form_type:).state).to eq(western_address.state)
        end
      end
    end
  end

  describe '#regional_office_for' do
    {
      eastern: ['VA', "VA Regional Office\nP.O. Box 4616\nBuffalo, NY 14240-4616"],
      central: ['CO', "VA Regional Office\nP.O. Box 4616\nBuffalo, NY 14240-4616"],
      western: ['AK', "VA Regional Office\nP.O. Box 8888\nMuskogee, OK 74402-8888"]
    }.each do |region, region_data|
      context "with a #{region} address" do
        before do
          new_form = education_benefits_claim.parsed_form
          new_form['educationProgram']['address']['state'] = region_data[0]
          education_benefits_claim.saved_claim.form = new_form.to_json
        end

        it 'returns the right address' do
          expect(described_class.regional_office_for(education_benefits_claim)).to eq(region_data[1])
        end
      end
    end
  end

  describe '#region_for' do
    context '22-1995' do
      it 'routes to Eastern RPO for former CENTRAL RPO state' do
        form = education_benefits_claim.parsed_form
        form['newSchool'] = {
          'address' => {
            state: 'IL'
          }
        }
        education_benefits_claim.saved_claim.form = form.to_json
        education_benefits_claim.saved_claim.form_id = '22-1995'
        expect(described_class.region_for(education_benefits_claim)).to eq(:eastern)
      end

      it 'routes to Eastern RPO' do
        form = education_benefits_claim.parsed_form
        education_benefits_claim.saved_claim.form = form.to_json
        education_benefits_claim.saved_claim.form_id = '22-1995'
        expect(described_class.region_for(education_benefits_claim)).to eq(:eastern)
      end
    end

    context '22-0994' do
      it 'routes to Eastern RPO' do
        education_benefits_claim.saved_claim.form_id = '22-0994'
        expect(described_class.region_for(education_benefits_claim)).to eq(:eastern)
      end
    end

    context '22-0993' do
      it 'routes to Western RPO' do
        education_benefits_claim.saved_claim.form_id = '22-0993'
        expect(described_class.region_for(education_benefits_claim)).to eq(:western)
      end
    end

    context '22-1990s' do
      it 'routes to Western RPO' do
        education_benefits_claim.saved_claim.form_id = '22-1990s'
        expect(described_class.region_for(education_benefits_claim)).to eq(:western)
      end
    end

    context 'address country Phillipines' do
      it 'routes to Western RPO' do
        form = education_benefits_claim.parsed_form
        form['educationProgram'] = {
          'address' => {
            country: 'PHL'
          }
        }
        education_benefits_claim.saved_claim.form = form.to_json
        education_benefits_claim.saved_claim.form_id = '22-1990'
        expect(described_class.region_for(education_benefits_claim)).to eq(:western)
      end
    end
  end
end
