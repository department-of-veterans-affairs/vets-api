# frozen_string_literal: true

require 'nokogiri'
require 'optparse'

def relative_file_path(file_path)
  file_path.start_with?('/') ? ".#{file_path}" : file_path
end

def extract_xml_attributes(file_path, mode)
  # Load XML content from the file
  xml_content = File.read(file_path)

  # Parse XML content using Nokogiri
  doc = Nokogiri::XML(xml_content)

  # Extract attributes from XML nodes
  seed = nil
  files = []
  doc.traverse do |node|
    seed = node.attributes['value'].value if node['name'] == 'seed'

    if node.element? && node.attributes['file']
      case mode
      when 'errors'
        if node.children.any? { |child| child.name == 'failure' }
          files << relative_file_path(node.attributes['file'].value)
        end
      when 'full'
        files << relative_file_path(node.attributes['file'].value)
      end
    end
  end

  # Flatten the array of attributes and join them into a string
  "bundle exec rspec --seed #{seed} --bisect #{files.uniq.join(' ')}"
rescue => e
  Rails.logger.debug { "Error: #{e.message}" }
end

options = {}

OptionParser.new do |opts|
  opts.banner = 'Usage: ruby extract_xml_attributes.rb [options] FILE_PATH'
  opts.on('-m', '--mode MODE', 'Mode: full or errors (default: errors)') do |m|
    options[:mode] = m.downcase
  end
end.parse!

file_path = ARGV.join(' ')

# Check if file path is provided
if file_path.nil?
  Rails.logger.debug 'Error: File path is required.'
  Rails.logger.debug 'Usage: ruby script.rb [options] FILE_PATH'
  exit(1)
end

# Set default mode to 'errors' if mode is not specified
mode = options[:mode] || 'errors'

# Call the method to extract XML attributes
xml_attributes = extract_xml_attributes(file_path, mode)

# Output the XML attributes
Rails.logger.debug { "\nRun the following commands in vets-api in order to debug:\n\n#{xml_attributes}" }
