require "spec_helper"

# Minimal ActiveRecord-shaped harness: enough callback surface for the
# concern to wire itself onto, without dragging in a database.
class FakeUser
  def self.after_commit(method_name, **options)
    committed_callbacks << [method_name, options]
  end

  def self.committed_callbacks
    @committed_callbacks ||= []
  end

  include Euromailing::Syncable
  euromailing_sync lists: ["list-1"], if: ->(u) { u.newsletter }

  def self.find_by(id:)
    store[id.to_s]
  end

  def self.store
    @store ||= {}
  end

  attr_accessor :id, :email, :first_name, :newsletter

  def initialize(id:, email:, first_name: nil, newsletter: true)
    @id = id
    @email = email
    @first_name = first_name
    @newsletter = newsletter
    self.class.store[id.to_s] = self
  end

  def euromailing_contact_attributes
    { email: email, first_name: first_name }
  end
end

RSpec.describe Euromailing::Syncable do
  let(:user) { FakeUser.new(id: 42, email: "jan@example.com", first_name: "Jan") }

  after { FakeUser.store.clear }

  it "registers after_commit callbacks for create/update and destroy" do
    expect(FakeUser.committed_callbacks).to include(
      [:euromailing_enqueue_upsert, { on: %i[create update] }],
      [:euromailing_enqueue_delete, { on: :destroy }]
    )
  end

  it "enqueues an upsert SyncJob with class name and id" do
    user.send(:euromailing_enqueue_upsert)

    job = ActiveJob::Base.queue_adapter.enqueued_jobs.last
    expect(job["job_class"] || job[:job]).to be_truthy
    expect(job[:args] || job["args"]).to eq(["upsert", "FakeUser", "42"])
  end

  it "enqueues a delete SyncJob with the captured email" do
    user.send(:euromailing_enqueue_delete)

    job = ActiveJob::Base.queue_adapter.enqueued_jobs.last
    expect(job[:args] || job["args"]).to eq(["delete", "jan@example.com"])
  end

  it "skips the upsert when the :if condition says no" do
    user.newsletter = false
    user.send(:euromailing_enqueue_upsert)
    expect(ActiveJob::Base.queue_adapter.enqueued_jobs).to be_empty
  end
end

RSpec.describe Euromailing::SyncJob do
  let(:client) { instance_double(Euromailing::Client) }
  before { allow(Euromailing).to receive(:client).and_return(client) }

  after { FakeUser.store.clear }

  it "upserts the contact and subscribes it to the configured lists" do
    FakeUser.new(id: 7, email: "jan@example.com", first_name: "Jan")

    expect(client).to receive(:upsert_contact)
      .with(email: "jan@example.com", first_name: "Jan")
    expect(client).to receive(:subscribe)
      .with(list_id: "list-1", email: "jan@example.com")

    described_class.perform_now("upsert", "FakeUser", "7")
  end

  it "does nothing when the record is gone by the time the job runs" do
    expect(client).not_to receive(:upsert_contact)
    described_class.perform_now("upsert", "FakeUser", "999")
  end

  it "deletes by email" do
    expect(client).to receive(:delete_contact).with(email: "jan@example.com")
    described_class.perform_now("delete", "jan@example.com")
  end

  it "treats a 404 on delete as success" do
    expect(client).to receive(:delete_contact)
      .and_raise(Euromailing::ApiError.new(status: 404, code: "not_found"))

    expect { described_class.perform_now("delete", "gone@example.com") }.not_to raise_error
  end
end
