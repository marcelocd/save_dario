require "mechanize.rb"
require 'nokogiri'
require 'byebug'
require 'json'
require 'csv'

def username
	'demo'
end

def password
	'demo'
end

def base_url
	"https:\/\/demo\.opencart\.com\/admin\/"
end

def build_customer body
	customer = {
		name: nil,
		email: nil,
		address: nil,
		city: nil,
		postcode: nil,
		country: nil,
		region: nil,
	}

	customer[:name] = customer_name(body)
	customer[:email] = body.css('#input-email')
								 				 .first
								 				 .attributes['value']
								 				 .text
								 				 .strip

	if body.css('#input-address-11') != []
		aux = body.css('#input-address-11')
							.first
		customer[:address] = aux.attributes['value']
									 				  .text
									 				  .strip unless aux.nil?
	end

	if body.css('#input-city1') != []
		aux = body.css('#input-city1')
							.first
		customer[:city] = aux.attributes['value']
									 			 .text
									 			 .strip unless aux.nil?
	end

	if body.css('#input-postcode1') != []
		aux = body.css('#input-address-11')
							.first
		customer[:postcode] = aux.attributes['value']
									 				   .text
									 				   .strip unless aux.nil?
	end

	if body.css('#input-country1') != []
		customer[:country] = body.css('#input-country1 option[@selected="selected"]')
														 .text
	end

	if body.css('#input-zone1') != []
		customer[:region] = body.css('#input-zone1 option[@selected="selected"]')
														.text
	end

	customer
end

def customer_name body
	whole_name = body.css('#input-firstname')
									 .first
									 .attributes['value']
									 .text
									 .strip
	whole_name += ' '
	whole_name += body.css('#input-lastname')
										.first
										.attributes['value']
										.text
										.strip
	whole_name.gsub(/\s{2,}/, ' ')
end

def print_customer customer
	puts '-' * 99
	puts "name: [#{customer[:name]}]"
	puts "email: [#{customer[:email]}]"
	puts "address: [#{customer[:address]}]"
	puts "city: [#{customer[:city]}]"
	puts "postcode: [#{customer[:postcode]}]"
	puts "country: [#{customer[:country]}]"
	puts "region: [#{customer[:region]}]"
end

def write_json_file customers
	tempHash = {}

	customers.each_with_index do |customer, index|
		tempHash["customer#{index}"] = customer
	end

	File.open("./customers.json","w") do |f|
	  f.write(tempHash.to_json)
	end
end

def write_csv_file
	CSV.open("./customers.csv", "wb") do |csv|
	  csv << ["name",
	  				"email",
	  				"address",
	  				"city",
	  				"postcode",
	  				"country",
	  				"region"]

	  json_file = File.read('./customers.json')

	  customers_hash = JSON.parse(json_file)
	  customers_hash.each do |key, value|
	  	customer_name = value['name']
	  	email = value['email']
	  	address = value['address']
	  	city = value['city']
	  	postcode = value['postcode']
	  	country = value['country']
	  	region = value['region']

	  	csv << [customer_name,
	  					email,
	  					address,
	  					city,
	  					postcode,
	  					country,
	  					region]
	  end
	end
end

@ag = Mechanize.new()

def main
	initial_page_url = base_url() + 'index.php?route=common/login'

	form_data = { username: username,
								password: password }

	initial_page = @ag.post(initial_page_url, form_data)

	user_token = initial_page.body
									 				 .match(/user_token=([^\"]+)/)[1]
	
	customers_page_url = base_url() +
											 "index.php?route=customer/customer&user_token=#{user_token}"

	customers_page = @ag.get(customers_page_url)
	current_page_number = 1

	customers = []

	edit_customer_urls = 
		customers_page.body
									.scan(/#{base_url}index\.php\?route=customer\/customer\/edit\&amp;user_token=[^\&]+\&amp;customer_id=\d+/)
									.map{ |link| link.gsub("\&amp;", "\&") }

	puts '-' * 99
	puts 'PAGE ' + current_page_number.to_s
	puts '-' * 99

	edit_customer_urls.each do | url |
		page = @ag.get(url)
		body = Nokogiri::HTML(page.body)

		customers << build_customer(body)
		print_customer(customers.last)
	end

	next_page_url = customers_page.body
																.match(/#{base_url}index\.php\?route=customer\/customer\&amp;user_token=[^\&]+\&amp;page=#{current_page_number + 1}/)
	
	while !next_page_url.nil? do
		next_page_url = next_page_url[0].gsub("\&amp;", "\&")
		current_page_number += 1

		customers_page = @ag.get(next_page_url)
   	
		edit_customer_urls = 
			customers_page.body
										.scan(/#{base_url}index\.php\?route=customer\/customer\/edit\&amp;user_token=[^\&]+\&amp;customer_id=\d+/)
										.map{ |link| link.gsub("\&amp;", "\&") }

		puts '-' * 99
		puts 'PAGE ' + current_page_number.to_s
		puts '-' * 99

		edit_customer_urls.each do | url |
			page = @ag.get(url)
			body = Nokogiri::HTML(page.body)

			customers << build_customer(body)
			print_customer(customers.last)
		end

		next_page_url = customers_page.body
																  .match(/#{base_url}index\.php\?route=customer\/customer\&amp;user_token=[^\&]+\&amp;page=#{current_page_number + 1}/)
	end

	write_json_file(customers)
	write_csv_file
end

main
