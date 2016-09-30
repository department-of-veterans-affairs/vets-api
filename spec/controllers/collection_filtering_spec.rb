# frozen_string_literal: true
require 'rails_helper'
require 'common/models/collection'

RSpec.describe ApplicationController, type: :controller do
  controller do
    skip_before_action :authenticate

    def index
      tt = []
      10.times do |i|
        tt << TriageTeam.new(
          triage_team_id: i,
          name: "name-#{i}",
          relation_type: 'patient'
        )
      end

      collection = Common::Collection.new(TriageTeam, data: tt)
      collection = params[:filter].present? ? collection.find_by(params[:filter]) : collection
      render json: collection.data,
             serializer: CollectionSerializer,
             each_serializer: TriageTeamSerializer,
             meta: collection.metadata
    end
  end

  before(:each) do
    routes.draw { get 'index' => 'anonymous#index' }
  end

  subject { JSON.parse(response.body)['data'] }

  it 'has a collection' do
    get :index
    expect(subject).to be_an(Array)
    expect(subject.length).to eq(10)
  end

  context 'filter with one attribute' do
    context 'and one predicate' do
      let(:params) { { filter: { name: { eq: 'name-1' } } } }
      it 'can filter on name eq' do
        get :index, params
        expect(subject).to be_an(Array)
        expect(subject.length).to eq(1)
        expect(subject.first['attributes']['name']).to eq('name-1')
      end
    end

    context 'and two predicates' do
      let(:params) { { filter: { triage_team_id: { gteq: '6', lteq: '9' } } } }
      it 'can filter on name eq (with coercion)' do
        get :index, params
        expect(subject).to be_an(Array)
        expect(subject.length).to eq(4)
      end
    end
  end

  context 'filter with two attributes' do
    let(:params) { { filter: { triage_team_id: { gteq: 6, lteq: 9 }, name: { not_eq: 'name-7' } } } }

    it 'can filter on name and id' do
      get :index, params
      expect(subject).to be_an(Array)
      expect(subject.length).to eq(3)
      expect(subject.map { |item| item['attributes']['name'] })
        .to_not include('name-7')
    end
  end
end
