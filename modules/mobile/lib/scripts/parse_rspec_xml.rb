require 'nokogiri'
require 'optparse'

def extract_xml_attributes(file_path, mode)
  begin
    # Load XML content from the file
    xml_content = File.read(file_path)

    # Parse XML content using Nokogiri
    doc = Nokogiri::XML(xml_content)

    # Extract attributes from XML nodes
    seed = nil
    files = []
    doc.traverse do |node|
      if node['name'] == 'seed'
        seed = node.attributes['value'].value
      end

      if node.element? && node.attributes['file']
        case mode
        when 'errors'
          if node.children.any? { |child| child.name == 'failure' }
            file_path = node.attributes['file'].value
            files << (file_path.start_with?('/') ? ".#{file_path}" : file_path)
          end
        when 'full'
          file_path = node.attributes['file'].value
          files << (file_path.start_with?('/') ? ".#{file_path}" : file_path)
        end
      end
    end

    # Flatten the array of attributes and join them into a string
    "bundle exec rspec --seed #{seed} --bisect #{files.uniq.join(' ')}"
  rescue StandardError => e
    puts "Error: #{e.message}"
  end
end

options = {}

OptionParser.new do |opts|
  opts.banner = "Usage: ruby extract_xml_attributes.rb [options] FILE_PATH"
  opts.on("-m", "--mode MODE", "Mode: full or errors (default: errors)") do |m|
    options[:mode] = m.downcase
  end
end.parse!

file_path = ARGV.join(' ')

# Check if file path is provided
if file_path.nil?
  puts "Error: File path is required."
  puts "Usage: ruby script.rb [options] FILE_PATH"
  exit(1)
end

# Set default mode to 'errors' if mode is not specified
mode = options[:mode] || "errors"

# Call the method to extract XML attributes
xml_attributes = extract_xml_attributes(file_path, mode)

# Output the XML attributes
puts "\nRun the following commands in vets-api in order to debug:\n\n#{xml_attributes}"
