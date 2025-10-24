require_relative '../../lib/integrations/finvalda/finvalda'

# Enable debug output for HTTP requests
HTTParty::Basement.default_options.update(debug_output: $stdout)

begin
  # Initialize the Finvalda client
  finvalda = Integrations::Finvalda.new
  
  puts "Testing connection to Finvalda API at #{finvalda.base_url}..."
  
  # Example 1: Get all services (XML format by default)
  puts "\n=== Example 1: Getting all services (XML format) ==="
  services_response = finvalda.get_services
  
  if services_response[:success]
    puts "Success! Services data (first 500 chars):"
    response = services_response[:data] || services_response[:raw_response]
    puts response.to_s[0..500] + (response.length > 500 ? '...' : '')
  else
    puts "Error getting services: #{services_response[:error]}"
  end
  
  # Example 2: Get specific service by code
  # Uncomment and replace 'SERVICE_CODE' with actual service code when needed
  # puts "\n=== Example 2: Getting specific service ==="
  # service_response = finvalda.get_services(
  #   service_code: 'SERVICE_CODE',
  #   format: :xml  # or :dataset
  # )
  # 
  # if service_response[:success]
  #   puts "Success! Service data:"
  #   pp service_response[:data] || service_response[:raw_response]
  # else
  #   puts "Error getting service: #{service_response[:error]}"
  # end
  
  # Example 2: Get products with filters (Dataset format)
  puts "\n=== Example 2: Getting filtered products (Dataset format) ==="
  filtered_products = finvalda.get_products(
    s_pre_kod: 'SOME_PRODUCT_CODE',  # Replace with actual product code
    t_koregavimo_data: '2024-01-01', # Modified after this date
    format: :dataset
  )
  
  if filtered_products[:success]
    puts "Success! Filtered products data (first 500 chars):"
    response = filtered_products[:data] || filtered_products[:raw_response]
    puts response.to_s[0..500] + (response.length > 500 ? '...' : '')
  else
    puts "Error getting filtered products: #{filtered_products[:error]}"
  end
  
  # Example 2: Insert a new item (commented out as it would modify data)
  # Uncomment and modify with actual data when ready to test
  # puts "\n=== Example 2: Inserting a new item ==="
  # item_data = {
  #   "Fvs.ObjektasI" => {
  #     "sKodas" => "OBJ1_TEST",
  #     "sPavadinimas" => "Testinis objektas"
  #   }
  # }
  # 
  # insert_response = finvalda.insert_new_item('Fvs.ObjektasI', item_data)
  # 
  # if insert_response[:success]
  #   puts "Success! Insert response:"
  #   pp insert_response[:data] || insert_response[:raw_response]
  # else
  #   puts "Error inserting item: #{insert_response[:error]}"
  # end
  
rescue StandardError => e
  puts "An error occurred: #{e.message}"
  puts e.backtrace.join("\n")
end
