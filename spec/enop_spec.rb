# frozen_string_literal: true

require "spec_helper"

RSpec.describe Enop do
  # let( :token ) { ENV.fetch("EN_DEV_TOKEN", nil) }
  let(:token) { ENV.fetch("EN_DEV_TOKEN", nil) }
  let(:url) { ENV.fetch("EN_NOTESTORE_URL", nil) }
  let(:env) { ENV.fetch("ENV", nil) }

  it "has a version number" do
    expect(Enop::VERSION).not_to be_nil
  end

  it "Enop get from local", cmd: :local do
    env ||= "production"
    enop = TestSetup.setup(token, url, env)
    ret = enop.list_notebooks(from_backup: false)
    # p "ret.size=#{ret.size}"
    expect(!ret.empty?).to be_truthy
    #    expect(ret).to eq(true)
  end

  it "Enop get from remote", cmd: :remote do
    env ||= "production"
    enop = TestSetup.setup(token, url, env)
    ret = enop.list_notebooks(from_backup: true)
    # p "ret.size=#{ret.size}"

    expect(!ret.empty?).to be_truthy
    #    expect(ret).to eq(true)
  end
end
