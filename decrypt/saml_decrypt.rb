#!/usr/bin/env ruby
# frozen_string_literal: true

require 'onelogin/ruby-saml'
require 'optparse'

KEY_PATH = 'decrypt.key'

@options = {}
OptionParser.new do |opts|
  opts.banner = 'Usage: samldecrypt.rb [options] <assertion file or standard input>'
  opts.on('-k', '--key KEY', 'Path to private key') do |k|
    @options[:key] = k
  end
  opts.parse!(ARGV)
end

def saml_settings
  settings = OneLogin::RubySaml::Settings.new
  settings.private_key = File.read(File.expand_path(@options[:key] || KEY_PATH))
  settings
end

ios = IO.new STDOUT.fileno
inputdoc = ARGF.read
saml_response = OneLogin::RubySaml::Response.new(inputdoc,
                                                 settings: saml_settings)

if saml_response.decrypted_document
  doc = +''
  saml_response.decrypted_document.write(doc)
  ios.write doc
elsif saml_response.response
  ios.write saml_response.response
end
