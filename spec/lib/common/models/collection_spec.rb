# frozen_string_literal: true

require 'rails_helper'
require 'common/models/collection'
require 'support/author'

describe Common::Collection do
  subject { described_class.new(klass, data: klass_array, metadata: { nobel_winner: 'Bob Dylan' }, errors: {}) }

  let(:klass)       { Author }
  let(:klass_array) { Array.new(25) { |i| attributes_for(:author, id: i + 1) } }

  it 'returns a JSON string' do
    expect(subject.to_json).to be_a(String)
  end

  it 'returns a JSON string whose keys' do
    json = JSON.parse(subject.to_json)
    expect(json.first.keys).to contain_exactly('id', 'first_name', 'last_name', 'birthdate', 'zipcode')
  end

  it 'can return members' do
    expect(subject.members).to be_an(Array)
    expect(subject.members.size).to eq(25)
  end

  it 'can return a single member' do
    expect(subject.members.first).to be_a(Author)
  end

  it 'can return metadata' do
    expect(subject.metadata).to include(nobel_winner: 'Bob Dylan')
  end

  context 'complex sort' do
    it 'can sort a collection in reverse' do
      collection = subject.sort('-id')
      expect(collection.map(&:id))
        .to eq((1..25).to_a.reverse)
      expect(collection.metadata[:sort]).to eq('id' => 'DESC')
    end

    it 'can sort a collection by multiple fields' do
      collection = subject.sort(%w[-first_name last_name])
      expect(collection.members.first.first_name).to eq('Zoe')
      expect(collection.members.last.first_name).to eq('Al')
      expectation = collection.members.each_cons(2).map do |a, b|
        (a.first_name == b.first_name && a.last_name < b.last_name) ||
          (a.first_name > b.first_name)
      end
      expect(expectation.all?).to be(true)
      expect(collection.metadata[:sort]).to eq('first_name' => 'DESC', 'last_name' => 'ASC')
    end

    it 'can sort nil values, nil is always last regardless of order' do
      subject.members[5].birthdate = nil
      subject.members[10].birthdate = nil
      subject.members[11].birthdate = nil
      subject.members[12].birthdate = nil
      expect(subject.members.map(&:birthdate).compact.size).to eq(21)
      collection = subject.sort('birthdate')
      expect(collection.members.last(4).map(&:birthdate)).to all(be_nil)
      collection = subject.sort('-birthdate')
      expect(collection.members.last(4).map(&:birthdate)).to all(be_nil)
    end
  end

  context 'complex filter' do
    let(:filter_eq) { { first_name: { eq: 'Al' } } }
    let(:filter_lteq_gteq) { { birthdate: { gteq: 58.years.ago, lteq: 25.years.ago } } }
    let(:filter_match) { { first_name: { match: 'oe' } } }
    let(:filter_not_eq) { { first_name: { not_eq: 'Zoe' } } }

    context 'with find_by' do
      it 'can filter for exact match' do
        filtered_collection = subject.find_by(filter_eq)
        expect(filtered_collection).to be_a(Common::Collection)
        expect(filtered_collection.members.map(&:first_name)).to all(eq('Al'))
        expect(filtered_collection.metadata)
          .to eq(nobel_winner: 'Bob Dylan', filter: filter_eq)
      end

      it 'can filter for a range with lteq and gteq' do
        filtered_collection = subject.find_by(filter_lteq_gteq)
        expect(filtered_collection).to be_a(Common::Collection)
        expect(filtered_collection.members.map(&:birthdate))
          .to all(be_between(58.years.ago, 25.years.ago))
        expect(filtered_collection.metadata)
          .to eq(nobel_winner: 'Bob Dylan', filter: filter_lteq_gteq)
      end

      it 'can filter for a partial match' do
        filtered_collection = subject.find_by(filter_match)
        expect(filtered_collection).to be_a(Common::Collection)
        expect(filtered_collection.members.map(&:first_name))
          .to all(eq('Zoe'))
        expect(filtered_collection.metadata)
          .to eq(nobel_winner: 'Bob Dylan', filter: filter_match)
      end

      it 'can filter for not_eq (inequality)' do
        filtered_collection = subject.find_by(filter_not_eq)
        expect(filtered_collection).to be_a(Common::Collection)
        expect(filtered_collection.members.map(&:first_name))
          .to all(eq('Al'))
        expect(filtered_collection.metadata)
          .to eq(nobel_winner: 'Bob Dylan', filter: filter_not_eq)
      end
    end

    context 'with find_first_by' do
      it 'can filter for exact match' do
        author = subject.find_first_by(filter_eq)
        expect(author).to be_a(Author)
        expect(author.first_name).to eq('Al')
      end

      it 'can filter for a range with lteq and gteq' do
        author = subject.find_first_by(filter_lteq_gteq)
        expect(author).to be_a(Author)
        expect(author.birthdate)
          .to be_between(58.years.ago, 25.years.ago)
      end

      it 'can filter for a partial match' do
        author = subject.find_first_by(filter_match)
        expect(author).to be_a(Author)
        expect(author.first_name)
          .to eq('Zoe')
      end

      it 'can filter for not_eq (inequality)' do
        author = subject.find_first_by(filter_not_eq)
        expect(author).to be_a(Author)
        expect(author.first_name)
          .to eq('Al')
      end
    end
  end

  context 'pagination' do
    it 'can paginate a collection' do
      paginated_collection = subject.paginate(per_page: 2)

      expect(paginated_collection).to be_a(Common::Collection)
      expect(paginated_collection.data.size).to eq(2)
      expect(paginated_collection.metadata)
        .to eq(nobel_winner: 'Bob Dylan',
               pagination: { current_page: 1, per_page: 2, total_pages: 13, total_entries: 25 })
    end
  end

  context 'null data' do
    let(:klass_array) { nil }

    it 'returns a JSON string' do
      expect(subject.to_json).to be_a(String)
    end

    it 'can return members' do
      expect(subject.members).to be_an(Array)
      expect(subject.members.size).to eq(0)
    end

    it 'can return a single member' do
      expect(subject.members.first).to be_nil
    end

    it 'can return metadata' do
      expect(subject.metadata).to include(nobel_winner: 'Bob Dylan')
    end

    context 'complex sort' do
      it 'can sort a collection in reverse' do
        collection = subject.sort('-id')
        expect(collection.members).to eq([])
        expect(collection.metadata[:sort]).to eq('id' => 'DESC')
      end

      it 'can sort a collection by multiple fields' do
        collection = subject.sort(%w[-first_name last_name])
        expect(collection.members).to eq([])
        expect(collection.metadata[:sort]).to eq('first_name' => 'DESC', 'last_name' => 'ASC')
      end
    end

    context 'complex filter' do
      let(:filter_eq) { { first_name: { eq: 'Al' } } }
      let(:filter_lteq_gteq) { { birthdate: { gteq: 58.years.ago, lteq: 25.years.ago } } }
      let(:filter_match) { { first_name: { match: 'oe' } } }
      let(:filter_not_eq) { { first_name: { not_eq: 'Zoe' } } }

      context 'with find_by' do
        it 'can filter for exact match' do
          filtered_collection = subject.find_by(filter_eq)
          expect(filtered_collection).to be_a(Common::Collection)
          expect(filtered_collection.members.map(&:first_name)).to all(eq('Al'))
          expect(filtered_collection.metadata)
            .to eq(nobel_winner: 'Bob Dylan', filter: filter_eq)
        end

        it 'can filter for a range with lteq and gteq' do
          filtered_collection = subject.find_by(filter_lteq_gteq)
          expect(filtered_collection).to be_a(Common::Collection)
          expect(filtered_collection.members.map(&:birthdate))
            .to all(be_between(58.years.ago, 25.years.ago))
          expect(filtered_collection.metadata)
            .to eq(nobel_winner: 'Bob Dylan', filter: filter_lteq_gteq)
        end

        it 'can filter for a partial match' do
          filtered_collection = subject.find_by(filter_match)
          expect(filtered_collection).to be_a(Common::Collection)
          expect(filtered_collection.members.map(&:first_name))
            .to all(eq('Zoe'))
          expect(filtered_collection.metadata)
            .to eq(nobel_winner: 'Bob Dylan', filter: filter_match)
        end

        it 'can filter for not_eq (inequality)' do
          filtered_collection = subject.find_by(filter_not_eq)
          expect(filtered_collection).to be_a(Common::Collection)
          expect(filtered_collection.members.map(&:first_name))
            .to all(eq('Al'))
          expect(filtered_collection.metadata)
            .to eq(nobel_winner: 'Bob Dylan', filter: filter_not_eq)
        end
      end

      context 'with find_first_by' do
        it 'can filter for exact match' do
          author = subject.find_first_by(filter_eq)
          expect(author).to be_nil
        end

        it 'can filter for a range with lteq and gteq' do
          author = subject.find_first_by(filter_lteq_gteq)
          expect(author).to be_nil
        end

        it 'can filter for a partial match' do
          author = subject.find_first_by(filter_match)
          expect(author).to be_nil
        end

        it 'can filter for not_eq (inequality)' do
          author = subject.find_first_by(filter_not_eq)
          expect(author).to be_nil
        end
      end
    end

    context 'pagination' do
      it 'can paginate a collection' do
        paginated_collection = subject.paginate(per_page: 2)

        expect(paginated_collection).to be_a(Common::Collection)
        expect(paginated_collection.data.size).to eq(0)
        expect(paginated_collection.metadata)
          .to eq(nobel_winner: 'Bob Dylan',
                 pagination: { current_page: 1, per_page: 2, total_pages: 1, total_entries: 0 })
      end
    end
  end

  describe 'caching' do
    let(:api_call) { { data: klass_array, metadata: { nobel_winner: 'Bob Dylan' }, errors: {} } }
    let(:loaded_data) { described_class.new(Author, **api_call) }

    it 'can cache based on passed block' do
      expect(Common::Collection).to receive(:cache).once.and_call_original
      expect(Oj).not_to receive(:load)
      result = Common::Collection.fetch(Author, cache_key: 'authors_key', ttl: 1000) do
        api_call
      end

      expect(result).to be_a(Common::Collection)
      expect(result.type).to eq(Author)
      expect(result.metadata).to eq(nobel_winner: 'Bob Dylan')
      expect(result.cached?).to be(true)
      expect(result.ttl).to be_between(0, 1000)
      expect(Common::Collection).to receive(:bust).with('authors_key')
      result.bust
    end

    it 'does not cache if cache_key is nil' do
      expect(Common::Collection).not_to receive(:cache)
      expect(Oj).not_to receive(:load)
      result = Common::Collection.fetch(Author, cache_key: nil, ttl: 1000) do
        api_call
      end

      expect(result).to be_a(Common::Collection)
      expect(result.type).to eq(Author)
      expect(result.metadata).to eq(nobel_winner: 'Bob Dylan')
      expect(result.cached?).to be(false)
      expect(result.ttl).to be_nil
      expect(Common::Collection).not_to receive(:bust).with('authors_key')
      expect(result.bust).to be_nil
    end

    context 'already cached values' do
      before do
        described_class.cache(loaded_data.serialize, 'authors_key', 1000)
      end

      it 'can fetch an already cached api call' do
        expect(Common::Collection).not_to receive(:cache)
        expect(Oj).to receive(:load).and_call_original
        result = Common::Collection.fetch(Author, cache_key: 'authors_key', ttl: 1000) do
          api_call
        end

        expect(result).to be_a(Common::Collection)
        expect(result.type).to eq(Author)
        expect(result.metadata).to eq('nobel_winner' => 'Bob Dylan')
        expect(result.cached?).to be(true)
        expect(result.ttl).to be_between(0, 1000)
        expect(Common::Collection).to receive(:bust).with('authors_key')
        result.bust
      end

      context 'cache busting' do
        it 'returns an array corresponding to an array of cache_keys that were provided to bust' do
          result = Common::Collection.bust(%w[authors_key unknown_key])
          expect(result).to eq([1, 0])
          result = Common::Collection.bust(%w[authors_key unknown_key])
          expect(result).to eq([0, 0])
        end
      end
    end
  end
end
