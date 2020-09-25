# coding: utf-8
RSpec.describe SimpleATM do
  include Rack::Test::Methods
  let(:app) { SimpleATM::API }
  
  def headers(**extra)
    {'CONTENT_TYPE' => 'application/json'}.merge(extra)
  end

  def call_api(endpoint, payload)
    post endpoint, payload.to_json, headers
    last_response
  end

  def deposit(payload)
    call_api '/simple/deposit', payload
  end

  def withdraw(payload)
    call_api '/simple/withdraw', payload
  end

  def random_denomination
    [1,2,5,10,25,50].sample
  end

  context "when empty" do
    before(:example) do
      @atm = SimpleATM.instance
      @atm.empty
    end
    
    it "won't allow withdrawls" do
      response = withdraw ({total: 1})
      expect(response.status).to eq 402
    end

    it "will allow withdrawls after a deposit" do
      response = deposit ({bills: [{'value' => 1,  'quantity' => 1000},
                                   {'value' => 2,  'quantity' => 1000},
                                   {'value' => 5,  'quantity' => 1000},
                                   {'value' => 10, 'quantity' => 1000},
                                   {'value' => 25, 'quantity' => 1000},
                                   {'value' => 50, 'quantity' => 1000}]})
      expect(response.status).to eq 201
      expect(@atm.total).to eq 93000

      withdrawl_amount = rand(1..93000)
      response = withdraw ({total: withdrawl_amount})
      expect(response.status).to eq 200
      expect(@atm.total).to eq (93000 - withdrawl_amount)
    end

    it "won't allow impossible withdrawls even after a deposit" do
      # Oh no!  Whoever just loaded this empty ATM only loaded the $50 bills
      # before going on break!  I sure hope nobody tries to withdraw a
      # non-multiple of $50 in the meantime...
      response = deposit ({bills: [{'value' => 50, 'quantity' => 1000}]})
      expect(response.status).to eq 201
      expect(@atm.total).to eq (50 * 1000)
      expect(@atm.bills 50).to eq 1000
      expect(@atm.bills 1).to eq 0

      # Here somebody comes oh gosh oh frick
      response = withdraw ({total: rand(1..49)})
      expect(response.status).to eq 402
      expect(@atm.total).to eq (50 * 1000)
      expect(@atm.bills 50).to eq 1000
      expect(@atm.bills 1).to eq 0
    end

    it "won't allow depositing bills with invalid denominations" do
      response = deposit ({bills: [{'value' => 3, 'quantity' => 1}]})
      expect(response.status).to eq 400
    end
  end

  context "when full" do
    before(:example) do
      @atm = SimpleATM.instance
      @atm.empty
      @atm.deposit [{'value' => 1,  'quantity' => 1000},
                    {'value' => 2,  'quantity' => 1000},
                    {'value' => 5,  'quantity' => 1000},
                    {'value' => 10, 'quantity' => 1000},
                    {'value' => 25, 'quantity' => 1000},
                    {'value' => 50, 'quantity' => 1000}]
    end

    it "will allow withdrawls" do
      amount = rand(1..93000)
      old_total = @atm.total
      response = withdraw ({total: amount})
      new_total = @atm.total

      expect(response.status).to eq 200
      expect(new_total).to eq (old_total - amount)
    end

    it "will allow deposits" do
      value = random_denomination
      quantity = rand(1..1000)
      old_total = @atm.total
      old_bills = @atm.bills(value)
      response = deposit ({bills: [{'value' => value, 'quantity' => quantity}]})
      new_total = @atm.total
      new_bills = @atm.bills(value)

      expect(response.status).to eq 201
      expect(new_total).to eq (old_total + (value * quantity))
      expect(new_bills).to eq (old_bills + quantity)
    end

    it "won't allow overdraws" do
      old_total = @atm.total
      response = withdraw ({total: old_total + rand(1..8675309)})
      new_total = @atm.total
      
      expect(response.status).to eq 402
      expect(new_total).to eq old_total
    end

    it "will dispense the correct number of bills" do
      amount = rand(1..1000)
      remainder = amount
      fifties     = remainder / 50; remainder = remainder % 50
      twentyfives = remainder / 25; remainder = remainder % 25
      tens        = remainder / 10; remainder = remainder % 10
      fives       = remainder / 5;  remainder = remainder % 5
      twos        = remainder / 2;  remainder = remainder % 2
      ones        = remainder
      
      response = withdraw ({total: amount})
      expect(response.status).to eq 200

      resp_body = JSON.parse(response.body)
      expect(resp_body).to be_instance_of Array

      returned_amount = 0
      
      resp_body.map do |row|
        expect([1,2,5,10,25,50]).to include row['value']
        case row['value']
        when 50
          expect(row['quantity']).to eq fifties
        when 25
          expect(row['quantity']).to eq twentyfives
        when 10
          expect(row['quantity']).to eq tens
        when 5
          expect(row['quantity']).to eq tens
        when 2
          expect(row['quantity']).to eq twos
        when 1
          expect(row['quantity']).to eq ones
        end

        returned_amount += row['value'] * row['quantity']
      end

      expect(returned_amount).to eq amount
    end

    it "won't allow impossible withdrawls" do
      # Oh no!  The ATM ran out of $1 bills!  I sure hope nobody tries to
      # withdraw another dollar...
      @atm.bills 1, -1000
      expect(@atm.bills 1).to eq 0

      response = withdraw ({total: 1})
      expect(response.status).to eq 402
      expect(@atm.bills 1).to eq 0
    end

    it "won't allow \"depositing\" negative quantities of bills" do
      value = [1,2,5,10,25,50].sample
      old_bills = @atm.bills value
      response = deposit ({bills: [{value: value, quantity: -1}]})
      expect(response.status).to eq 400
      expect(@atm.bills value).to eq old_bills
    end

    it "won't allow depositing fractions of bills" do
      value = [1,2,5,10,25,50].sample
      old_bills = @atm.bills value
      response = deposit ({bills: [{value: value, quantity: rand(0.01..0.99)}]})
      expect(response.status).to eq 400
      expect(@atm.bills value).to eq old_bills
    end

    it "won't allow \"withdrawing\" negative amounts of money" do
      old_total = @atm.total
      response = withdraw ({total: -1})
      expect(response.status).to eq 400
      expect(@atm.total).to eq old_total
    end

    it "won't allow withdrawing fractions of bills" do
      old_total = @atm.total
      response = withdraw ({total: rand(0.01..0.99)})
      expect(response.status).to eq 400
      expect(@atm.total).to eq old_total
    end
  end
end
