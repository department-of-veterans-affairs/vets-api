namespace :vet360 do

  # SETUP
  VET360_HOST = 'http://google.com' #@TODO
  
  @headers = {
    "Content-Type" => "application/json",
    "Accept" => "application/json"
  }

  # TASKS
  desc "Request Vet360 person contact information"
  task :get_contactinfo, [:vet360_id] => [:environment] do |t, args|
    abort "No vet360_id provided" if args[:vet360_id].blank?
    path = "/cuf/person/contact-information/v1/" + args[:vet360_id]
    response = make_request(:get, path)
  end

  desc "Request Vet360 person contact information addresses"
  task :get_contactinfo_addresses, [:vet360_id] => [:environment] do |t, args|
    abort "No vet360_id provided" if args[:vet360_id].blank?
    path = "/cuf/person/contact-information/v1/" + args[:vet360_id] + "/addresses"
    response = make_request(:get, path)
  end

  desc "Request Vet360 person contact information emails"
  task :get_contactinfo_emails, [:vet360_id] => [:environment] do |t, args|
    abort "No vet360_id provided" if args[:vet360_id].blank?
    path = "/cuf/person/contact-information/v1/" + args[:vet360_id] + "/emails"
    response = make_request(:get, path)
  end

  desc "Request Vet360 person contact information telephones"
  task :get_contactinfo_telephones, [:vet360_id] => [:environment] do |t, args|
    abort "No vet360_id provided" if args[:vet360_id].blank?
    path = "/cuf/person/contact-information/v1/" + args[:vet360_id] + "/telephones"
    response = make_request(:get, path)
  end

  def conn
    conn = Faraday.new(
      VET360_HOST, ssl: { verify: false }
      ) do |faraday|
      faraday.adapter :httpclient
    end
  end

  def make_request method, route, body = nil

    response = conn.send(method) do |req|
      req.url route
      req.headers = @headers
      req.body = body
    end

    # print results to console
    puts "#{method.upcase}: " + route
    puts "Response status: " + response.status.to_s
    puts "Response body: " + response.body

  end


end