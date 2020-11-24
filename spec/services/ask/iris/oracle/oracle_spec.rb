# frozen_string_literal: true

require 'rspec'
require 'rails_helper'

RSpec.describe 'Ask::Iris::Oracle' do
  context 'when condition' do
    field_list = Ask::Iris::Oracle::FIELD_LIST
    it 'transforms vet statuses' do

      expect(field_list[6][:transform].call('dependent')).to eql('for the Dependent of a Veteran')
      expect(field_list[6][:transform].call('vet')).to eql('for Myself as a Veteran (I am the Vet)')
      expect(field_list[6][:transform].call('general')).to eql('General Question (Vet Info Not Needed)')
      expect(field_list[6][:transform].call('behalf of vet')).to eql('for, about, or on behalf of a Veteran')
    end
    it 'transforms preferred contact method' do
      expect(field_list[10][:transform].call('phone')).to eql('Telephone')
      expect(field_list[10][:transform].call('email')).to eql('E-Mail')
      expect(field_list[10][:transform].call('mail')).to eql('US Mail')
    end
    it 'transforms date' do
      expect(Ask::Iris::Oracle.transform_date('1976-05-07')).to eql('05-07-1976')
    end
    it 'transforms state' do
      expect(Ask::Iris::Oracle.transform_state('AK')).to eql('Alaska')
    end
    it 'transforms country' do
      expect(Ask::Iris::Oracle.transform_country('AGO')).to eql('Angola')
    end
  end
end
