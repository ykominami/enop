require 'spec_helper'

RSpec.describe Enop do
  # let( :token ) { ENV.fetch("EN_DEV_TOKEN", nil) }
  let( :token ) { ENV["EN_DEV_TOKEN"] }
  let( :url ) { ENV.fetch("EN_NOTESTORE_URL", nil) }
  let( :env ) { ENV.fetch("ENV", nil) }

  it 'has a version number' do
    expect(Enop::VERSION).not_to be_nil
  end

  it 'Enop get from local' , cmd: :local  do
    remote = false
    env ||= "production"
    enop = TestSetup.setup(token, url, env)
    ret = enop.list_notebooks(remote)

    expect(ret).not_to be_nil
#    expect(ret).to eq(true)
  end

  it 'Enop get from remote' , cmd: :remote do
    remote = true
    env ||= "production"
    enop = TestSetup.setup(token, url, env)
    ret = enop.list_notebooks(remote)

    expect(ret).not_to be_nil
#    expect(ret).to eq(true)
  end
end
