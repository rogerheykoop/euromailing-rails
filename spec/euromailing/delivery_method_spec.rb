require "spec_helper"

RSpec.describe Euromailing::DeliveryMethod do
  let(:mail) do
    Mail.new do
      from     "MyApp <noreply@app.example.com>"
      to       "user@example.com"
      reply_to "support@app.example.com"
      subject  "Your invoice"

      text_part { body "plain" }
      html_part do
        content_type "text/html; charset=UTF-8"
        body "<p>rich</p>"
      end
    end
  end

  it "delivers through the global client by default" do
    stub = stub_request(:post, "https://euromailing.com/api/v1/transactional_emails")
      .with(body: hash_including(
        "from"      => "MyApp <noreply@app.example.com>",
        "to"        => "user@example.com",
        "subject"   => "Your invoice",
        "html_body" => "<p>rich</p>",
        "text_body" => "plain",
        "reply_to"  => "support@app.example.com"
      ))
      .to_return(status: 202, body: '{"id":"x"}')

    described_class.new.deliver!(mail)
    expect(stub).to have_been_requested
  end

  it "uses per-mailer settings (api_key / base_url) when given" do
    stub = stub_request(:post, "https://other.example.com/api/v1/transactional_emails")
      .with(headers: { "Authorization" => "Bearer other_key" })
      .to_return(status: 202, body: "{}")

    described_class.new(api_key: "other_key", base_url: "https://other.example.com").deliver!(mail)
    expect(stub).to have_been_requested
  end

  it "encodes attachments" do
    mail.add_file filename: "invoice.pdf", content: "%PDF-fake"
    stub = stub_request(:post, "https://euromailing.com/api/v1/transactional_emails")
      .with { |req|
        att = JSON.parse(req.body)["attachments"].first
        att["filename"] == "invoice.pdf" && Base64.strict_decode64(att["content"]) == "%PDF-fake"
      }
      .to_return(status: 202, body: "{}")

    described_class.new.deliver!(mail)
    expect(stub).to have_been_requested
  end

  it "refuses multi-recipient mail" do
    mail.to = ["a@example.com", "b@example.com"]
    expect { described_class.new.deliver!(mail) }
      .to raise_error(Euromailing::DeliveryMethod::DeliveryError, /exactly one recipient/)
  end

  it "handles bare text-only mail" do
    simple = Mail.new(from: "noreply@app.example.com", to: "user@example.com",
                      subject: "hi", body: "just text")
    stub = stub_request(:post, "https://euromailing.com/api/v1/transactional_emails")
      .with { |req|
        parsed = JSON.parse(req.body)
        parsed["text_body"] == "just text" && !parsed.key?("html_body")
      }
      .to_return(status: 202, body: "{}")

    described_class.new.deliver!(simple)
    expect(stub).to have_been_requested
  end
end
