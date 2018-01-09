# frozen_string_literal: true

RSpec.shared_examples 'emis_soap_response' do |example_response_file, response_class|
  let(:faraday_response) { instance_double('Faraday::Response') }
  let(:body) { Ox.parse(File.read(example_response_file)) }
  let(:response) { response_class.new(faraday_response) }

  before(:each) do
    allow(faraday_response).to receive(:body) { body }
  end

  describe 'checking status' do
    it 'returns true for ok?' do
      expect(response).to be_ok
    end
  end

  describe 'returning items' do
    it 'returns the items' do
      expect(response.items.count).to eq(response.locate(response.item_tag_name).count)
    end

    def verify_item(item, item_tag, schema)
      item_tag.nodes.each do |node|
        next unless node.respond_to?(:value)
        field_name = node.value.sub(/NS\d+:/, '')
        verify_item_field(schema, field_name, item, item_tag, node) if schema[field_name]
      end
    end

    def verify_item_field(schema, field_name, item, item_tag, node)
      if schema[field_name][:schema]
        local_item_name = schema[field_name][:rename] || field_name.snakecase
        local_items = item.send(local_item_name)
        local_items.each_with_index do |local_item, idx|
          local_item_tag = response.locate(field_name, item_tag)[idx]
          verify_item(local_item, local_item_tag, schema[field_name][:schema])
        end
      else
        field_name = schema[field_name][:rename] || field_name.snakecase
        field_value = item.send(field_name)
        value = cast_value(node, field_value)
        message = "Expected #{field_name} to equal #{value}, got #{item.send(field_name)}"
        expect(item.send(field_name)).to(eq(value), message)
      end
    end

    def cast_value(node, field_value)
      value = node.nodes.first
      value = value.to_i if field_value.is_a?(Integer)
      value = value.to_f if field_value.is_a?(Float)
      value = Date.parse(value) if field_value.is_a?(Date)
      value
    end

    it 'has all the right fields in the response' do
      response.items.each_with_index do |item, idx|
        item_tag = response.locate(response.item_tag_name)[idx]
        verify_item(item, item_tag, response.item_schema)
      end
    end
  end
end
