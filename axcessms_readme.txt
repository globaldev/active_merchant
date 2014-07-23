## Usage

The best way to understand how to work with Axcessms Gateway is to check the tests:
	- test/unit/gateways/axcessms_test.rb - this is a Test that mocks gateway responses and doesn't need a real server. 
	- test/remote/gateways/remote_axcessms_test.rb - this is a real remote test to a real test server. 

1. Create Axcessms Gateway instance
	- using test fixture
		    gateway = AxcessmsGateway.new(fixtures(:axcessms)) - in this case please set merchant authorization data in test/fixtures.yml file.
	- directly - you need to know 4 authorization strings as described below
		
		    gateway = AxcessmsGateway.new(
		    {
		      :sender => sender string,
		      :login => login string,
		      :password => password ,
		      :channel => channel id string,
		    })
		    
3. Make a request

  cc_card = credit_card('4200000000000000', month: 05, year: 2022)
  options['TRANSACTION.MODE'] = 'INTEGRATOR_TEST'
  options['PRESENTATION.USAGE'] = "Order Number 1231231"
  options['IDENTIFICATION.TRANSACTIONID'] = "asd23421ds2134"
  options[:address] = {
    :street => "Sunny street",
    :city => "New York",
    :country => "US",
  }
  post[:currency] = 'USD'
  
  #amount is always in cents 
  amount = 150 
  	
  auth = gateway.authorize(amount, credit_card, options)
  capture = @gateway.capture(nil, auth.authorization)

4. Parameters
	All parameters can be used as it's specified in POST documentation except CC Card and amount. 