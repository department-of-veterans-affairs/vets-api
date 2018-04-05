namespace :vet360 do

  ###########
  ## SETUP ##
  ###########
  VET360_HOST = 'http://google.com' #@TODO
  
  @headers = {
    "Content-Type" => "application/json",
    "Accept" => "application/json"
  }
  @base_path = "/cuf/person/contact-information/v1"
  @cuf_system_name = "aSystemName" # @TODO

  ###########
  ## TASKS ##
  ###########

  ## GETs

  desc "Request Vet360 person contact information"
  task :get_contactinfo, [:vet360_id] => [:environment] do |t, args|
    abort "No vet360_id provided" if args[:vet360_id].blank?
    path = "#{@base_path}/#{args[:vet360_id]}"
    response = make_request(:get, path)
  end

  desc "Request Vet360 person contact information addresses"
  task :get_contactinfo_addresses, [:vet360_id] => [:environment] do |t, args|
    abort "No vet360_id provided" if args[:vet360_id].blank?
    path = "#{@base_path}/#{args[:vet360_id]}/addresses"
    response = make_request(:get, path)
  end

  desc "Request Vet360 person contact information emails"
  task :get_contactinfo_emails, [:vet360_id] => [:environment] do |t, args|
    abort "No vet360_id provided" if args[:vet360_id].blank?
    path = "#{@base_path}/#{args[:vet360_id]}/emails"
    response = make_request(:get, path)
  end

  desc "Request Vet360 person contact information telephones"
  task :get_contactinfo_telephones, [:vet360_id] => [:environment] do |t, args|
    abort "No vet360_id provided" if args[:vet360_id].blank?
    path = "#{@base_path}/#{args[:vet360_id]}/telephones"
    response = make_request(:get, path)
  end

  desc "Request Vet360 email transaction"
  task :get_transaction_emails, [:vet360_id, :tx_audit_id] => [:environment] do |t, args|
    abort "No vet360_id provided" if args[:vet360_id].blank?
    abort "No tx_audit_id provided" if args[:tx_audit_id].blank?
    path = "#{@base_path}/#{args[:vet360_id]}/emails/#{:tx_audit_id}"
    response = make_request(:get, path, nil, {cufSystemName: @cuf_system_name})
  end

  desc "Request Vet360 addresses transaction"
  task :get_transaction_addresses, [:vet360_id, :tx_audit_id] => [:environment] do |t, args|
    abort "No vet360_id provided" if args[:vet360_id].blank?
    abort "No tx_audit_id provided" if args[:tx_audit_id].blank?
    path = "#{@base_path}/#{args[:vet360_id]}/addresses/#{:tx_audit_id}"
    response = make_request(:get, path, nil, {cufSystemName: @cuf_system_name})
  end

  desc "Request Vet360 telephones transaction"
  task :get_transaction_telephones, [:vet360_id, :tx_audit_id] => [:environment] do |t, args|
    abort "No vet360_id provided" if args[:vet360_id].blank?
    abort "No tx_audit_id provided" if args[:tx_audit_id].blank?
    path = "#{@base_path}/#{args[:vet360_id]}/telephones/#{:tx_audit_id}"
    response = make_request(:get, path, nil, {cufSystemName: @cuf_system_name})
  end

  ## Posts

  desc "Create Vet360 person contact information addresses"
  task :post_contactinfo_addresses, [:body] => [:environment] do |t, args|
    abort "No body provided" if args[:body].blank?
    path = "#{@base_path}/addresses"
    response = make_request(:post, path, args[:body], {cufSystemName: @cuf_system_name}) #@TODO
  end

  desc "Create Vet360 person contact information emails"
  task :post_contactinfo_emails, [:body] => [:environment] do |t, args|
    abort "No body provided" if args[:body].blank?
    path = "#{@base_path}/emails"
    response = make_request(:post, path, args[:body], {cufSystemName: @cuf_system_name}) #@TODO
  end

  desc "Create Vet360 person contact information telephones"
  task :post_contactinfo_telephones, [:body] => [:environment] do |t, args|
    abort "No body provided" if args[:body].blank?
    path = "#{@base_path}/telephones"
    response = make_request(:post, path, args[:body], {cufSystemName: @cuf_system_name}) #@TODO
  end

  #############
  ## Helpers ##
  #############
  def conn
    conn = Faraday.new(
      VET360_HOST, ssl: { verify: false }
      ) do |faraday|
      faraday.adapter :httpclient
    end
  end

  def make_request method, route, body = nil, headers = {}

    response = conn.send(method) do |req|
      req.url route
      req.headers = @headers + headers
      req.body = body
    end

    # print results to console
    puts "#{method.upcase}: " + route
    puts "Response status: " + response.status.to_s
    puts "Response body: " + response.body

  end


end