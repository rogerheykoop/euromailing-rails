require "spec_helper"

RSpec.describe Euromailing::Client do
  let(:client) { Euromailing.client }

  describe "#deliver_transactional" do
    it "POSTs the payload with bearer auth and returns the parsed response" do
      stub = stub_request(:post, "https://euromailing.com/api/v1/transactional_emails")
        .with(
          headers: { "Authorization" => "Bearer eml_live_test", "Content-Type" => "application/json" },
          body: hash_including("from" => "App <noreply@app.example.com>", "to" => "user@example.com")
        )
        .to_return(status: 202, body: { id: "kumo-1", status: "queued" }.to_json)

      result = client.deliver_transactional(
        from: "App <noreply@app.example.com>", to: "user@example.com",
        subject: "Hi", html_body: "<p>hi</p>"
      )

      expect(stub).to have_been_requested
      expect(result["id"]).to eq("kumo-1")
    end

    it "omits nil fields from the payload" do
      stub_request(:post, "https://euromailing.com/api/v1/transactional_emails")
        .with { |req| !JSON.parse(req.body).key?("reply_to") }
        .to_return(status: 202, body: "{}")

      client.deliver_transactional(from: "a@b.c", to: "d@e.f", subject: "s", text_body: "t")
    end

    it "raises ApiError with the machine-readable code on rejection" do
      stub_request(:post, "https://euromailing.com/api/v1/transactional_emails")
        .to_return(status: 422, body: { error: { code: "from_domain_mismatch", message: "nope" } }.to_json)

      expect {
        client.deliver_transactional(from: "a@b.c", to: "d@e.f", subject: "s", text_body: "t")
      }.to raise_error(Euromailing::ApiError) { |e|
        expect(e.status).to eq(422)
        expect(e.code).to eq("from_domain_mismatch")
      }
    end
  end

  describe "contacts" do
    it "upserts by email" do
      stub = stub_request(:post, "https://euromailing.com/api/v1/contacts/upsert")
        .with(body: { contact: { email: "jan@example.com", first_name: "Jan" } }.to_json)
        .to_return(status: 201, body: { email: "jan@example.com", created: true }.to_json)

      result = client.upsert_contact(email: "jan@example.com", first_name: "Jan")
      expect(stub).to have_been_requested
      expect(result["created"]).to be(true)
    end

    it "deletes by email (204 → nil)" do
      stub_request(:delete, "https://euromailing.com/api/v1/contacts/by_email")
        .with(body: { email: "jan@example.com" }.to_json)
        .to_return(status: 204)

      expect(client.delete_contact(email: "jan@example.com")).to be_nil
    end
  end

  describe "lists" do
    it "subscribes an email to a list" do
      stub = stub_request(:post, "https://euromailing.com/api/v1/lists/list-1/memberships")
        .with(body: { email: "jan@example.com" }.to_json)
        .to_return(status: 201, body: { subscribed: true }.to_json)

      client.subscribe(list_id: "list-1", email: "jan@example.com")
      expect(stub).to have_been_requested
    end

    it "unsubscribes an email from a list" do
      stub = stub_request(:delete, "https://euromailing.com/api/v1/lists/list-1/memberships")
        .with(body: { email: "jan@example.com" }.to_json)
        .to_return(status: 204)

      client.unsubscribe(list_id: "list-1", email: "jan@example.com")
      expect(stub).to have_been_requested
    end
  end

  describe "sending domains" do
    it "creates a sending domain and returns DNS instructions" do
      stub = stub_request(:post, "https://euromailing.com/api/v1/sending_domains")
        .with(body: { domain: "coachklant.nl" }.to_json)
        .to_return(status: 201, body: {
          domain: "coachklant.nl", status: "pending",
          dns_records: [{ purpose: "dkim", type: "CNAME" }]
        }.to_json)

      result = client.create_sending_domain("coachklant.nl")
      expect(stub).to have_been_requested
      expect(result["status"]).to eq("pending")
      expect(result["dns_records"].first["purpose"]).to eq("dkim")
    end

    it "fetches verification status by domain" do
      stub = stub_request(:get, "https://euromailing.com/api/v1/sending_domains/coachklant.nl")
        .to_return(status: 200, body: { domain: "coachklant.nl", verified: false }.to_json)

      expect(client.sending_domain("coachklant.nl")["verified"]).to be(false)
      expect(stub).to have_been_requested
    end

    it "triggers a fresh verification" do
      stub = stub_request(:post, "https://euromailing.com/api/v1/sending_domains/coachklant.nl/verify")
        .to_return(status: 200, body: { verified: true }.to_json)

      expect(client.verify_sending_domain("coachklant.nl")["verified"]).to be(true)
      expect(stub).to have_been_requested
    end

    it "deletes a sending domain (204 -> nil)" do
      stub = stub_request(:delete, "https://euromailing.com/api/v1/sending_domains/coachklant.nl")
        .to_return(status: 204)

      expect(client.delete_sending_domain("coachklant.nl")).to be_nil
      expect(stub).to have_been_requested
    end

    it "lists sending domains" do
      stub = stub_request(:get, "https://euromailing.com/api/v1/sending_domains")
        .to_return(status: 200, body: "[]")

      expect(client.sending_domains).to eq([])
      expect(stub).to have_been_requested
    end

    it "surfaces from_domain_not_on_account as an ApiError" do
      stub_request(:post, "https://euromailing.com/api/v1/sending_domains")
        .to_return(status: 422, body: { error: { code: "validation_failed", message: "bad" } }.to_json)

      expect { client.create_sending_domain("x") }
        .to raise_error(Euromailing::ApiError) { |e| expect(e.status).to eq(422) }
    end
  end

  it "raises ConfigurationError without an api_key" do
    Euromailing.reset!
    expect {
      Euromailing.client.lists
    }.to raise_error(Euromailing::ConfigurationError)
  end

  it "honours a custom base_url" do
    Euromailing.configure { |c| c.base_url = "https://staging.euromailing.com" }
    stub = stub_request(:get, "https://staging.euromailing.com/api/v1/lists")
      .to_return(status: 200, body: "[]")

    Euromailing.client.lists
    expect(stub).to have_been_requested
  end
end
