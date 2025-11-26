class FinvaldaService
  def initialize
    @client = Integrations::Finvalda::Finvalda.new
  end

  def authenticate
    @client.authenticate
  end

  def get_invoices(filters = {})
    with_authentication do
      response = HTTParty.get(
        "#{@client.base_url}/api/invoices",
        headers: @client.headers,
        query: filters
      )
      
      handle_response(response)
    end
  end

  def get_invoice(invoice_id)
    with_authentication do
      response = HTTParty.get(
        "#{@client.base_url}/api/invoices/#{invoice_id}",
        headers: @client.headers
      )
      
      handle_response(response)
    end
  end

  def create_invoice(invoice_data)
    with_authentication do
      response = HTTParty.post(
        "#{@client.base_url}/api/invoices",
        headers: @client.headers,
        body: invoice_data.to_json
      )
      
      handle_response(response)
    end
  end

  private

  def with_authentication
    authenticate unless @client.authenticated?
    
    if @client.authenticated?
      yield
    else
      { success: false, error: 'Authentication failed' }
    end
  rescue StandardError => e
    { success: false, error: e.message }
  end

  def handle_response(response)
    if response.success?
      { success: true, data: response.parsed_response }
    else
      { 
        success: false, 
        error: response.parsed_response['message'] || 'API request failed',
        status: response.code
      }
    end
  end
end
